import SwiftUI
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
    @State private var chatSession: ChatSession?
    @State private var didStartMonitoring = false
    @State private var showManagement = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @SceneStorage("activeChannelId") private var storedActiveChannelId: String?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var lastIRCConfiguration: IRCConfiguration?
    @State private var selectedDetailTab: DetailTab = .chat

    init(authManager: AuthManager, connectionSupervisor: IRCConnectionSupervisor, configuration: AppConfiguration) {
        self.authManager = authManager
        self.connectionSupervisor = connectionSupervisor
        self.configuration = configuration

        let settings = ChatSettings()
        let channelStore = ChannelStore(settings: settings)
        _chatSettings = StateObject(wrappedValue: settings)
        _channelStore = StateObject(wrappedValue: channelStore)
        _connectionStore = StateObject(wrappedValue: connectionSupervisor.statusStore())

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
        let identityStore = UserIdentityStore(usersService: usersService)

        let socialTabStore = SocialTabStore(settings: settings)

        let whisperService = HelixWhisperService(client: helixClient)
        let eventSubClient = EventSubClient(helixClient: helixClient)
        let whisperStore = WhisperStore(whisperService: whisperService, eventSubClient: eventSubClient)

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
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                phoneLayout
            } else {
                ipadLayout
            }
        }
        .environmentObject(emoteStore)
        .environmentObject(badgeStore)
        .environmentObject(providerStatusStore)
        .environmentObject(identityStore)
        .environmentObject(socialTabStore)
        .environmentObject(whisperStore)
        .environmentObject(userProfileStore)
        .environmentObject(moderationContext)
        .environmentObject(commandStore)
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
                authManager.restoreSession()
                await authManager.refreshIfNeeded()
                if case .signedIn = authManager.state {
                    await identityStore.refresh()
                }
            }
        }
        .onChange(of: authManager.state) { _, newState in
            switch newState {
            case .signedIn:
                Task { await identityStore.refresh() }
            case .signedOut, .error:
                identityStore.clear()
                whisperStore.stop()
                whisperStore.clearAll()
            case .signingIn:
                break
            }
        }
        .onChange(of: identityStore.user) { _, newUser in
            if let user = newUser {
                whisperStore.start(userId: user.id, userLogin: user.login, userName: user.displayName)
            } else {
                whisperStore.stop()
            }
        }
        .onChange(of: channelStore.channels) { _, _ in
            syncActiveChannel()
            syncConnectionStates()
            refreshProviders()
        }
        .onChange(of: channelStore.activeChannelId) { _, newValue in
            storedActiveChannelId = newValue
            if let id = newValue {
                channelStore.markChannelRead(channelId: id)
            }
            refreshProviders()
        }
        .onChange(of: connectionStore.state) { _, _ in
            syncConnectionStates()
        }
    }

    private var isSigningIn: Bool {
        if case .signingIn = authManager.state { return true }
        return false
    }

    private var isSignedIn: Bool {
        if case .signedIn = authManager.state { return true }
        return false
    }

    private var authStateText: String {
        switch authManager.state {
        case .signedOut:
            return "Signed out"
        case .signingIn:
            return "Signing in..."
        case .signedIn(let token):
            return "Signed in (token: \(tokenPreview(token.accessToken)))"
        case .error(let message):
            return "Auth error: \(message)"
        }
    }

    private func tokenPreview(_ token: String) -> String {
        let prefix = token.prefix(6)
        return "\(prefix)..."
    }

    private func connectIRC() {
        guard case let .signedIn(token) = authManager.state else { return }
        let ircConfig = IRCConfiguration(
            nickname: configuration.defaultNick,
            user: configuration.defaultUser,
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
        chatSession = ChatSession(
            supervisor: connectionSupervisor,
            channelStore: channelStore,
            channel: channelStore.activeChannelId
        )
        connectionSupervisor.connect(configuration: ircConfig, channels: channels)
    }

    private func reconnectNow() {
        guard let configuration = lastIRCConfiguration else { return }
        let channels = channelStore.channels.map { $0.id }
        connectionSupervisor.disconnect(reason: "Manual reconnect")
        connectionSupervisor.connect(configuration: configuration, channels: channels)
    }

    private var phoneLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView

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

            if channelStore.channels.isEmpty {
                emptyStateView
            } else {
                TabView(selection: activeChannelBinding) {
                    ForEach(channelStore.channels) { channel in
                        channelDetail(for: channel)
                            .tag(Optional(channel.id))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .padding()
    }

    private var ipadLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(alignment: .leading, spacing: 12) {
                headerView
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
            .padding(.top, 8)
        } detail: {
            if let channel = activeChannel {
                channelDetail(for: channel)
                    .padding()
            } else {
                emptyStateView
                    .padding()
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DankChat iOS")
                .font(.title2)
                .bold()

            if !configuration.isConfigured {
                Text("Update Config.plist with Twitch client info.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ConnectionStatusView(store: connectionStore)

            VStack(alignment: .leading, spacing: 8) {
                Text(authStateText)
                    .font(.subheadline)

                HStack {
                    Button("Sign In") {
                        Task { await authManager.beginLogin() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!configuration.isConfigured || isSigningIn)

                    Button("Sign Out") {
                        authManager.signOut()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isSignedIn)
                }
            }

            HStack {
                Button("Connect IRC") {
                    connectIRC()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isSignedIn || !configuration.isConfigured)

                Button("Disconnect") {
                    connectionSupervisor.disconnect(reason: "User requested")
                }
                .buttonStyle(.bordered)
            }

            ChatSettingsView(settings: chatSettings)
        }
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

            Picker("View", selection: $selectedDetailTab) {
                ForEach(DetailTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
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
            .onChange(of: store.entries.count) { _, _ in
                guard let event = store.entries.last else { return }
                let mention = isMention(event)
                channelStore.recordIncomingEvent(
                    channelId: channel.id,
                    isMention: mention
                )
                socialTabStore.append(event: event, identity: identityStore.user)
            }
            .frame(minHeight: 240)

            ChatComposerView(
                connectionStore: connectionStore,
                session: chatSession,
                channel: channel.id
            )
        }
    }

    private var activeChannel: Channel? {
        guard let activeId = channelStore.activeChannelId else { return nil }
        return channelStore.channels.first(where: { $0.id == activeId })
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

    private static let classifier = SocialMessageClassifier()

    private func isMention(_ event: ChatEvent) -> Bool {
        guard case .message(let message) = event else { return false }

        // Prefer authenticated identity from the identity store.
        if let identity = identityStore.user {
            return Self.classifier.isMention(message: message, identity: identity)
        }

        // Fall back to static config defaults when not signed in.
        let tokens = [configuration.defaultNick, configuration.defaultUser]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return false }
        let lowerText = message.text.lowercased()
        return tokens.contains { lowerText.contains($0.lowercased()) }
    }
}
