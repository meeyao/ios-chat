import Foundation
import DankChatCore

/// Routes mapped chat events into unread state, social tabs, notifications,
/// TTS, and highlight evaluation. Always runs on the main actor.
@MainActor
final class ChatEventRouter {
    private let channelStore: ChannelStore
    private let socialTabStore: SocialTabStore
    private let identityStore: UserIdentityStore
    private let highlightStore: HighlightStore
    private let ignoreStore: IgnoreStore
    private let notificationService: ChatNotificationService
    private let toolsStore: ToolsStore
    private let ttsService: TextToSpeechService
    private let fallbackMentionTokens: [String]

    private static let classifier = SocialMessageClassifier()

    init(
        channelStore: ChannelStore,
        socialTabStore: SocialTabStore,
        identityStore: UserIdentityStore,
        highlightStore: HighlightStore,
        ignoreStore: IgnoreStore,
        notificationService: ChatNotificationService,
        toolsStore: ToolsStore,
        ttsService: TextToSpeechService,
        fallbackMentionTokens: [String]
    ) {
        self.channelStore = channelStore
        self.socialTabStore = socialTabStore
        self.identityStore = identityStore
        self.highlightStore = highlightStore
        self.ignoreStore = ignoreStore
        self.notificationService = notificationService
        self.toolsStore = toolsStore
        self.ttsService = ttsService
        self.fallbackMentionTokens = fallbackMentionTokens
    }

    func handle(_ event: ChatEvent, channelId: String) {
        guard case .message(let message) = event else { return }
        guard !ignoreStore.isIgnored(message) else { return }

        let mention = isMention(event)
        let highlight = highlightStore.match(for: event)

        channelStore.recordIncomingEvent(
            channelId: channelId,
            isMention: mention || highlight != nil
        )
        socialTabStore.append(event: event, identity: identityStore.user)

        if mention {
            notificationService.notifyMention(message: message, channel: channelId)
        } else if let highlight, highlight.createNotification {
            notificationService.notifyHighlight(message: message, channel: channelId)
        }

        if channelId == channelStore.activeChannelId {
            ttsService.speak(message, settings: toolsStore.settings)
        }
    }

    private func isMention(_ event: ChatEvent) -> Bool {
        guard case .message(let message) = event else { return false }

        if let identity = identityStore.user {
            return Self.classifier.isMention(message: message, identity: identity)
        }

        guard !fallbackMentionTokens.isEmpty else { return false }
        let lowerText = message.text.lowercased()
        return fallbackMentionTokens.contains { lowerText.contains($0.lowercased()) }
    }
}
