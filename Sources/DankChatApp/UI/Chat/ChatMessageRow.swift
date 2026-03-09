import SwiftUI
import DankChatCore

struct ChatMessageRow: View {
    let message: ChatMessage
    @ObservedObject var settings: ChatSettings
    @EnvironmentObject private var emoteStore: EmoteStore
    @EnvironmentObject private var badgeStore: BadgeStore
    @EnvironmentObject private var userProfileStore: UserProfileStore
    @EnvironmentObject private var identityStore: UserIdentityStore
    @EnvironmentObject private var moderationContext: ModerationContext
    @ObservedObject private var badgeVisibility = BadgeVisibilitySettings.shared
    @State private var showReplyThread = false
    @State private var showUserPopup = false
    @State private var showModerationSheet = false

    private static let badgeProviderOrder: [ProviderID] = [.twitch, .sevenTV, .bttv, .ffz]

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let reply = message.replyMetadata {
                replyIndicator(reply: reply)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if settings.showTimestamps {
                    Text(Self.timestampFormatter.string(from: message.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 48, alignment: .leading)
                }

                if !visibleBadges.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(visibleBadges) { badge in
                            BadgeView(badge: badge)
                        }
                    }
                }

                if settings.showUsernames {
                    Button {
                        showUserPopup = true
                    } label: {
                        Text(message.user.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(usernameColor ?? .primary)
                    }
                    .buttonStyle(.plain)
                }

                ChatRichTextView(message: message, settings: settings, emoteStore: emoteStore)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            if let moderatorId = identityStore.user?.id {
                Button {
                    showModerationSheet = true
                } label: {
                    Label("Moderate", systemImage: "shield.lefthalf.filled")
                }
            }
        }
        .sheet(isPresented: $showReplyThread) {
            ReplyThreadView(message: message, settings: settings)
        }
        .sheet(isPresented: $showUserPopup) {
            UserPopupView(
                store: userProfileStore,
                userId: message.user.id,
                login: message.user.login,
                displayName: message.user.displayName,
                channelId: message.channel,
                currentUserId: identityStore.user?.id
            )
        }
        .sheet(isPresented: $showModerationSheet) {
            if let moderatorId = identityStore.user?.id {
                    ModerationActionSheet(
                        message: message,
                        channelId: message.channel,
                        moderatorId: moderatorId,
                        moderationService: moderationContext.moderationService,
                        chatMessagesService: moderationContext.chatMessagesService,
                        channelStore: moderationContext.channelStore
                    )
            }
        }
    }

    @ViewBuilder
    private func replyIndicator(reply: ReplyMetadata) -> some View {
        Button {
            showReplyThread = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.caption2)
                Text("Replying to \(reply.parentDisplayName ?? reply.parentUserLogin ?? "unknown")")
                    .font(.caption2)
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var visibleBadges: [Badge] {
        let resolved = badgeStore.resolveBadges(for: message)
        let filtered = resolved.filter { badgeVisibility.isBadgeVisible($0) }
        return filtered.sorted { lhs, rhs in
            let leftRank = providerRank(lhs.provider)
            let rightRank = providerRank(rhs.provider)
            if leftRank != rightRank {
                return leftRank < rightRank
            }
            if lhs.badgeId != rhs.badgeId {
                return lhs.badgeId < rhs.badgeId
            }
            return lhs.version < rhs.version
        }
    }

    private func providerRank(_ provider: ProviderID) -> Int {
        Self.badgeProviderOrder.firstIndex(of: provider) ?? Self.badgeProviderOrder.count
    }

    private var usernameColor: Color? {
        UsernameColor.color(from: message.user.color)
    }
}

#Preview {
    let settings = ChatSettings()
    let configuration = OAuthConfiguration(clientId: "", redirectURI: "", scopes: [])
    let twitchProvider = TwitchEmoteProvider(configuration: configuration, tokenProvider: { nil })
    let twitchBadgeProvider = TwitchBadgeProvider(configuration: configuration, tokenProvider: { nil })
    let emoteStore = EmoteStore(
        twitchProvider: twitchProvider,
        bttvProvider: BTTVEmoteProvider(),
        ffzProvider: FFZEmoteProvider(),
        sevenTVProvider: SevenTVEmoteProvider()
    )
    let badgeStore = BadgeStore(twitchProvider: twitchBadgeProvider)
    let helixClient = HelixAPIClient(clientId: "", tokenProvider: { nil })
    let usersService = HelixUsersService(client: helixClient)
    let identityStore = UserIdentityStore(usersService: usersService)
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
    let channelStore = ChannelStore(settings: settings)
    let moderationContext = ModerationContext(
        moderationService: moderationService,
        chatMessagesService: chatMessagesService, chatSettingsService: HelixChatSettingsService(client: helixClient),
        channelStore: channelStore
    )
    let user = ChatUser(displayName: "kappa", login: "kappa")
    let message = ChatMessage(
        id: "1",
        user: user,
        text: "Hello https://twitch.tv",
        timestamp: Date(),
        receivedAt: Date(),
        channel: "dankchat"
    )

    ChatMessageRow(message: message, settings: settings)
        .environmentObject(emoteStore)
        .environmentObject(badgeStore)
        .environmentObject(identityStore)
        .environmentObject(userProfileStore)
        .environmentObject(moderationContext)
        .padding()
}
