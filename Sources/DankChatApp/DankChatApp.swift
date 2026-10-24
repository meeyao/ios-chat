import SwiftUI
import UIKit
import DankChatCore

@main
struct DankChatApp: App {
    @StateObject private var authManager: AuthManager
    private let connectionSupervisor: IRCConnectionSupervisor
    private let configuration: AppConfiguration

    init() {
        let configuration = AppConfiguration.load()
        ImagePipeline.configure()
        let tokenStore = KeychainTokenStore(
            service: configuration.keychainService,
            account: configuration.keychainAccount
        )
        let oauthClient = OAuthClient(configuration: configuration.oauthConfiguration)
        let authorizer = SystemOAuthAuthorizer()
        let authManager = AuthManager(
            configuration: configuration.oauthConfiguration,
            tokenStore: tokenStore,
            oauthClient: oauthClient,
            authorizer: authorizer
        )

        self.configuration = configuration
        self.connectionSupervisor = IRCConnectionSupervisor()
        _authManager = StateObject(wrappedValue: authManager)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                authManager: authManager,
                connectionSupervisor: connectionSupervisor,
                configuration: configuration
            )
        }
    }
}

/// Segment options for the channel detail area.
private enum DetailTab: String, CaseIterable, Identifiable {
    case chat = "Chat"
    case mentions = "Mentions"
    case replies = "Replies"
    case whispers = "Whispers"

    var id: String { rawValue }
}

private struct ContentView: View {
    @ObservedObject var authManager: AuthManager
    let connectionSupervisor: IRCConnectionSupervisor
    let configuration: AppConfiguration

    @StateObject private var chatSettings: ChatSettings
    @StateObject private var channelStore: ChannelStore
    @StateObject private var connectionStore: ConnectionStatusStore
    @StateObject private var providerStatusStore: ProviderStatusStore
    @StateObject private var emoteStore: EmoteStore
    @StateObject private var badgeStore: BadgeStore
    @StateObject private var identityStore: UserIdentityStore
    @StateObject private var socialTabStore: SocialTabStore
    @StateObject private var whisperStore: WhisperStore
    @StateObject private var userProfileStore: UserProfileStore
    @StateObject private var moderationContext: ModerationContext
    @StateObject private var commandStore: CommandStore
    @StateObject private var highlightStore: HighlightStore
    @StateObject private var ignoreStore: IgnoreStore
    @StateObject private var notificationService: ChatNotificationService
    @StateObject private var toolsStore: ToolsStore
    @StateObject private var recentUploadsStore: RecentUploadsStore
    @StateObject private var streamStore: StreamStore
    @StateObject private var ttsService: TextToSpeechService
    private let usersService: HelixUsersService
    private let eventRouter: ChatEventRouter
    @State private var chatSession: ChatSession?
    @State private var didStartMonitoring = false
    @State private var showManagement = false
    @State private var showSettings = false
    @State private var showChatSettings = false
    @State private var devicePrompt: AuthManager.DeviceLoginPrompt?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @SceneStorage("activeChannelId") private var storedActiveChannelId: String?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var lastIRCConfiguration: IRCConfiguration?
    @State private var selectedDetailTab: DetailTab = .chat
    @State private var broadcasterIdCache: [String: String] = [:]

    init(authManager: AuthManager, connectionSupervisor: IRCConnectionSupervisor, configuration: AppConfiguration) {
        self.authManager = authManager
        self.connectionSupervisor = connectionSupervisor
        self.configuration = configuration

        let settings = ChatSettings()
        let channelStore = ChannelStore(settings: settings)
        let highlightStore = HighlightStore()
        let ignoreStore = IgnoreStore()
        let notificationService = ChatNotificationService()
        let toolsStore = ToolsStore()
        let recentUploadsStore = RecentUploadsStore()
        let ttsService = TextToSpeechService()
        _chatSettings = StateObject(wrappedValue: settings)
        _channelStore = StateObject(wrappedValue: channelStore)
        _connectionStore = StateObject(wrappedValue: connectionSupervisor.statusStore)
        _highlightStore = StateObject(wrappedValue: highlightStore)
        _ignoreStore = StateObject(wrappedValue: ignoreStore)
        _notificationService = StateObject(wrappedValue: notificationService)
        _toolsStore = StateObject(wrappedValue: toolsStore)
        _recentUploadsStore = StateObject(wrappedValue: recentUploadsStore)
        _ttsService = StateObject(wrappedValue: ttsService)

        let providerStatusStore = ProviderStatusStore()
        let tokenProvider: () async -> String? = { [weak authManager] in
            guard let authManager else { return nil }
            if case let .signedIn(token) = authManager.state {
                return token.accessToken
            }
            return nil
        }

        let twitchEmoteProvider = TwitchEmoteProvider(
            configuration: configuration.oauthConfiguration,
            tokenProvider: tokenProvider
        )
        let emoteStore = EmoteStore(
            twitchProvider: twitchEmoteProvider,
            bttvProvider: BTTVEmoteProvider(),
            ffzProvider: FFZEmoteProvider(),
            sevenTVProvider: SevenTVEmoteProvider(),
            providerStatus: providerStatusStore
        )

        let twitchBadgeProvider = TwitchBadgeProvider(
            configuration: configuration.oauthConfiguration,
            tokenProvider: tokenProvider
        )
        let badgeStore = BadgeStore(twitchProvider: twitchBadgeProvider, providerStatus: providerStatusStore)

        let helixClient = HelixAPIClient(
            clientId: configuration.oauthConfiguration.clientId,
            tokenProvider: tokenProvider
        )
        let usersService = HelixUsersService(client: helixClient)
        self.usersService = usersService
        let identityStore = UserIdentityStore(usersService: usersService)
        let streamStore = StreamStore(service: HelixStreamsService(client: helixClient))
        _streamStore = StateObject(wrappedValue: streamStore)

        let socialTabStore = SocialTabStore(settings: settings)

        let whisperService = HelixWhisperService(client: helixClient)
        let eventSubClient = EventSubClient(helixClient: helixClient)
        let whisperStore = WhisperStore(whisperService: whisperService, eventSubClient: eventSubClient)
        whisperStore.onIncomingWhisper = { [weak notificationService] message in
            guard !ignoreStore.isIgnored(login: message.fromUserLogin, displayName: message.fromUserName) else { return }
            notificationService?.notifyWhisper(message)
        }

        let profileService = HelixUserProfileService(client: helixClient)
        let followageService = HelixFollowageService(client: helixClient)
        let blockService = HelixBlockService(client: helixClient)
        let userProfileStore = UserProfileStore(
            profileService: profileService,
            followageService: followageService,
            blockService: blockService
        )

        let moderationService = HelixModerationService(client: helixClient)
        let chatMessagesService = HelixChatMessagesService(client: helixClient)
        let chatSettingsService = HelixChatSettingsService(client: helixClient)
        let moderationContext = ModerationContext(
            moderationService: moderationService,
            chatMessagesService: chatMessagesService,
            chatSettingsService: chatSettingsService,
            channelStore: channelStore
        )

        let commandStore = CommandStore()

        _providerStatusStore = StateObject(wrappedValue: providerStatusStore)
        _emoteStore = StateObject(wrappedValue: emoteStore)
        _badgeStore = StateObject(wrappedValue: badgeStore)
        _identityStore = StateObject(wrappedValue: identityStore)
        _socialTabStore = StateObject(wrappedValue: socialTabStore)
        _whisperStore = StateObject(wrappedValue: whisperStore)
        _userProfileStore = StateObject(wrappedValue: userProfileStore)
        _moderationContext = StateObject(wrappedValue: moderationContext)
        _commandStore = StateObject(wrappedValue: commandStore)

        let fallbackTokens = [configuration.defaultNick, configuration.defaultUser]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.eventRouter = ChatEventRouter(
            channelStore: channelStore,
            socialTabStore: socialTabStore,
            identityStore: identityStore,
            highlightStore: highlightStore,
            ignoreStore: ignoreStore,
            notificationService: notificationService,
            toolsStore: toolsStore,
            ttsService: ttsService,
            fallbackMentionTokens: fallbackTokens
        )
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                phoneLayout
            } else {
                ipadLayout
            }
        }
        .environmentObject(authManager)
        .environmentObject(emoteStore)
        .environmentObject(badgeStore)
        .environmentObject(providerStatusStore)
        .environmentObject(identityStore)
        .environmentObject(socialTabStore)
        .environmentObject(whisperStore)
        .environmentObject(userProfileStore)
        .environmentObject(moderationContext)
        .environmentObject(commandStore)
        .environmentObject(chatSettings)
        .environmentObject(highlightStore)
        .environmentObject(ignoreStore)
        .environmentObject(notificationService)
        .environmentObject(toolsStore)
        .environmentObject(recentUploadsStore)
        .environmentObject(streamStore)
        .environmentObject(ttsService)
        .sheet(isPresented: $showSettings) {
            AppSettingsView()
                .environmentObject(authManager)
                .environmentObject(chatSettings)
                .environmentObject(highlightStore)
                .environmentObject(ignoreStore)
                .environmentObject(notificationService)
                .environmentObject(toolsStore)
                .environmentObject(recentUploadsStore)
                .environmentObject(streamStore)
                .environmentObject(commandStore)
        }
        .sheet(isPresented: $showChatSettings) {
            NavigationStack {
                ScrollView {
                    ChatSettingsView(settings: chatSettings, roomStateContext: roomStateContext)
                        .padding()
                }
                .navigationTitle("Chat Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { showChatSettings = false }
                    }
                }
            }
            .environmentObject(badgeStore)
            .environmentObject(moderationContext)
        }
        .sheet(item: $devicePrompt) { prompt in
            DeviceLoginView(prompt: prompt) {
                authManager.cancelLogin()
                devicePrompt = nil
            }
        }
        .onChange(of: authManager.devicePrompt) { prompt in
            devicePrompt = prompt
        }
        .sheet(isPresented: $showManagement) {
            ChannelManagementView(
                store: channelStore,
                onJoin: { channel in chatSession?.join(channel: channel) },
                onPart: { channel in chatSession?.part(channel: channel) }
            )
        }
        .task {
            if !didStartMonitoring {
                didStartMonitoring = true
                connectionSupervisor.startMonitoring()
                streamStore.updateChannels(channelStore.channels.map(\.id))
                UIApplication.shared.isIdleTimerDisabled = chatSettings.keepScreenOn
                await notificationService.requestAuthorization()
                authManager.restoreSession()
                await authManager.refreshIfNeeded()
                if case .signedIn = authManager.state {
                    await identityStore.refresh()
                }
            }
        }
        .onChange(of: authManager.state) { newState in
            switch newState {
            case .signedIn:
                Task { await identityStore.refresh() }
                streamStore.updateChannels(channelStore.channels.map(\.id))
            case .signedOut, .error:
                identityStore.clear()
                whisperStore.stop()
                whisperStore.clearAll()
                streamStore.stop()
                ttsService.stop()
                chatSession = nil
                lastIRCConfiguration = nil
                connectionSupervisor.disconnect(reason: "Signed out")
            case .signingIn:
                break
            }
        }
        .onChange(of: identityStore.user) { newUser in
            if let user = newUser {
                whisperStore.start(userId: user.id, userLogin: user.login, userName: user.displayName)
                if isSignedIn, chatSession == nil {
                    connectIRC()
                }
            } else {
                whisperStore.stop()
            }
            resolveBroadcasterIdIfNeeded()
        }
        .onChange(of: channelStore.channels) { _ in
            syncActiveChannel()
            syncConnectionStates()
            refreshProviders()
            streamStore.updateChannels(channelStore.channels.map(\.id))
        }
        .onChange(of: channelStore.activeChannelId) { newValue in
            storedActiveChannelId = newValue
            if let id = newValue {
                channelStore.markChannelRead(channelId: id)
            }
            refreshProviders()
            resolveBroadcasterIdIfNeeded()
        }
        .onChange(of: connectionStore.state) { _ in
            syncConnectionStates()
        }
        .onChange(of: chatSettings.keepScreenOn) { newValue in
            UIApplication.shared.isIdleTimerDisabled = newValue
        }
        .preferredColorScheme(chatSettings.theme.colorScheme)
    }

    private var isSigningIn: Bool {
        if case .signingIn = authManager.state { return true }
        return false
    }

    private var isSignedIn: Bool {
        if case .signedIn = authManager.state { return true }
        return false
    }

    private var isConnected: Bool {
        if case .connected = connectionStore.state { return true }
        return false
    }

    private func connectIRC() {
        guard case let .signedIn(token) = authManager.state else { return }
        guard let user = identityStore.user else { return }
        let ircConfig = IRCConfiguration(
            nickname: user.login,
            user: user.login,
            oauthToken: token.accessToken
        )
        lastIRCConfiguration = ircConfig
        if channelStore.channels.isEmpty, !configuration.defaultChannel.isEmpty {
            channelStore.addChannel(name: configuration.defaultChannel)
        }
        let channels = channelStore.channels.map { $0.id }
        if channelStore.activeChannelId == nil {
            channelStore.setActive(id: channels.first ?? "")
        }
        let session = ChatSession(
            supervisor: connectionSupervisor,
            channelStore: channelStore,
            channel: channelStore.activeChannelId
        )
        session.onEvent = { [eventRouter] event, channelId in
            eventRouter.handle(event, channelId: channelId)
        }
        chatSession = session
        connectionSupervisor.connect(configuration: ircConfig, channels: channels)
    }

    private func reconnectNow() {
        guard let configuration = lastIRCConfiguration else { return }
        let channels = channelStore.channels.map { $0.id }
        connectionSupervisor.disconnect(reason: "Manual reconnect")
        connectionSupervisor.connect(configuration: configuration, channels: channels)
    }

    private var phoneLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            topBar

            if isSignedIn {
                ChannelTabStripView(
                    store: channelStore,
                    selection: activeChannelBinding,
                    connectionState: { channel in
                        channelStore.state(for: channel.id)?.connectionState ?? .disconnected(reason: nil)
                    },
                    onRename: handleRename,
                    onRemove: handleRemove,
                    onTogglePin: { channel in
                        channelStore.setPinned(id: channel.id, isPinned: !channel.isPinned)
                    },
                    onReconnect: { _ in reconnectNow() },
                    onManage: { showManagement = true }
                )

                if let channel = activeChannel {
                    channelDetail(for: channel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    emptyStateView
                }
            } else {
                signedOutView
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var ipadLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(alignment: .leading, spacing: 8) {
                topBar
                if isSignedIn {
                    ChannelListView(
                        store: channelStore,
                        selection: activeChannelBinding,
                        connectionState: { channel in
                            channelStore.state(for: channel.id)?.connectionState ?? .disconnected(reason: nil)
                        },
                        onRename: handleRename,
                        onRemove: handleRemove,
                        onTogglePin: { channel in
                            channelStore.setPinned(id: channel.id, isPinned: !channel.isPinned)
                        },
                        onReconnect: { _ in reconnectNow() },
                        onManage: { showManagement = true }
                    )
                }
            }
            .padding(.top, 8)
        } detail: {
            if !isSignedIn {
                signedOutView
            } else if let channel = activeChannel {
                channelDetail(for: channel)
                    .padding()
            } else {
                emptyStateView
                    .padding()
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Text("DankChat")
                .font(.headline)

            if isSignedIn {
                ConnectionStatusView(store: connectionStore)
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.body)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Settings")
        }
    }

    private var signedOutView: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 54))
                .foregroundStyle(.purple)

            Text("DankChat")
                .font(.largeTitle.weight(.bold))

            Text("Twitch chat for iPhone and iPad")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !configuration.isConfigured {
                Text("Add your Twitch Client ID in Settings → Twitch Login first.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            Button {
                authManager.beginLogin()
            } label: {
                Label("Sign In with Twitch", systemImage: "person.crop.circle.badge.checkmark")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!configuration.isConfigured || isSigningIn)

            if isSigningIn {
                ProgressView("Waiting for Twitch...")
                    .font(.footnote)
            }

            if case .error(let message) = authManager.state {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("Settings") {
                showSettings = true
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Text("No channels yet")
                .font(.headline)
            Text("Add a channel to start chatting.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Add Channel") {
                showManagement = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func channelDetail(for channel: Channel) -> some View {
        let store = channelStore.store(for: channel.id)
        return VStack(spacing: 12) {
            ProviderOutageBannerView()
                .padding(.horizontal, 4)

            StreamPanelView(channel: channel.id)

            HStack(spacing: 8) {
                Picker("View", selection: $selectedDetailTab) {
                    ForEach(DetailTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    showChatSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Chat settings")
            }
            .padding(.horizontal, 4)

            Group {
                switch selectedDetailTab {
                case .chat:
                    ChatTimelineView(
                        store: store,
                        settings: chatSettings,
                        isAtBottom: isAtBottomBinding(for: channel.id),
                        lastReadMessageId: lastReadBinding(for: channel.id)
                    )
                case .mentions:
                    MentionsTabView(settings: chatSettings)
                case .replies:
                    RepliesTabView(settings: chatSettings)
                case .whispers:
                    WhispersTabView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)

            if chatSettings.showInput {
                ChatComposerView(
                    connectionStore: connectionStore,
                    session: chatSession,
                    channel: channel.id
                )
                .disabled(chatSettings.autoDisableInput && !isConnected)
            }
        }
    }

    private var activeChannel: Channel? {
        guard let activeId = channelStore.activeChannelId else { return nil }
        return channelStore.channels.first(where: { $0.id == activeId })
    }

    private var roomStateContext: RoomStateContext? {
        guard let channel = activeChannel else { return nil }
        guard let moderatorId = identityStore.user?.id else { return nil }
        guard let broadcasterId = broadcasterIdCache[channel.id] else { return nil }
        let roomState = channelStore.state(for: channel.id)?.roomState ?? RoomState()
        let hasManageScope: Bool
        if case let .signedIn(token) = authManager.state {
            hasManageScope = token.scope.contains(HelixScope.moderatorManageChatSettings)
        } else {
            hasManageScope = false
        }
        return RoomStateContext(
            channelId: channel.id,
            broadcasterId: broadcasterId,
            moderatorId: moderatorId,
            roomState: roomState,
            hasManageScope: hasManageScope
        )
    }

    private var activeChannelBinding: Binding<String?> {
        Binding(
            get: { channelStore.activeChannelId },
            set: { newValue in
                guard let id = newValue else { return }
                channelStore.setActive(id: id)
                channelStore.markChannelRead(channelId: id)
                storedActiveChannelId = id
            }
        )
    }

    private func isAtBottomBinding(for channelId: String) -> Binding<Bool> {
        Binding(
            get: { channelStore.state(for: channelId)?.isAtBottom ?? true },
            set: { newValue in
                let lastRead = channelStore.state(for: channelId)?.lastReadMessageId
                channelStore.updateScrollState(
                    channelId: channelId,
                    isAtBottom: newValue,
                    lastReadMessageId: lastRead
                )
            }
        )
    }

    private func lastReadBinding(for channelId: String) -> Binding<String?> {
        Binding(
            get: { channelStore.state(for: channelId)?.lastReadMessageId },
            set: { newValue in
                let isAtBottom = channelStore.state(for: channelId)?.isAtBottom ?? true
                channelStore.updateScrollState(
                    channelId: channelId,
                    isAtBottom: isAtBottom,
                    lastReadMessageId: newValue
                )
            }
        )
    }

    private func handleRename(_ channel: Channel, _ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let oldId = channel.id
        chatSession?.part(channel: oldId)
        channelStore.renameChannel(id: oldId, newName: trimmed)
        let normalized = Channel.normalizeId(trimmed)
        if !normalized.isEmpty {
            chatSession?.join(channel: normalized)
        }
    }

    private func handleRemove(_ channel: Channel) {
        channelStore.removeChannel(id: channel.id)
        chatSession?.part(channel: channel.id)
    }

    private func syncActiveChannel() {
        if let stored = storedActiveChannelId,
           channelStore.channels.contains(where: { $0.id == stored }) {
            channelStore.setActive(id: stored)
            return
        }
        if channelStore.activeChannelId == nil, let first = channelStore.channels.first {
            channelStore.setActive(id: first.id)
        }
    }

    private func syncConnectionStates() {
        channelStore.updateAllConnectionStates(connectionStore.state)
    }

    private func refreshProviders() {
        let channels = channelStore.channels
        Task {
            for channel in channels {
                await emoteStore.loadChannelEmotes(channelLogin: channel.id)
                await badgeStore.loadChannelBadges(channelLogin: channel.id)
            }
        }
    }

    private func resolveBroadcasterIdIfNeeded() {
        guard let channel = activeChannel else { return }
        guard broadcasterIdCache[channel.id] == nil else { return }
        guard case .signedIn = authManager.state else { return }

        Task {
            do {
                let users = try await usersService.getUsers(logins: [channel.id])
                guard let broadcaster = users.first else { return }
                await MainActor.run {
                    broadcasterIdCache[channel.id] = broadcaster.id
                }
            } catch {
                return
            }
        }
    }

}
