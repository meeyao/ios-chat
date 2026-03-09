import Foundation

/// Provides moderation service dependencies to SwiftUI views via `@EnvironmentObject`.
///
/// Created once in the app shell and injected into the view hierarchy.
/// Views that need moderation capabilities (e.g. `ModerationActionSheet`) read
/// the services and channel store from this context.
@available(macOS 12.0, iOS 15.0, *)
@MainActor
public final class ModerationContext: ObservableObject {
    /// The Helix moderation service for ban/timeout/unban actions.
    public let moderationService: HelixModerationService

    /// The Helix chat messages service for delete message/clear chat actions.
    public let chatMessagesService: HelixChatMessagesService

    /// The Helix chat settings service for room state controls (slow/followers/subs/emote/unique).
    public let chatSettingsService: HelixChatSettingsService

    /// The channel store used to append moderation feedback to the timeline.
    public let channelStore: ChannelStore

    /// Creates a new moderation context.
    ///
    /// - Parameters:
    ///   - moderationService: The ban/timeout/unban service.
    ///   - chatMessagesService: The delete message/clear chat service.
    ///   - chatSettingsService: The chat settings service for room mode controls.
    ///   - channelStore: The channel store for timeline feedback.
    public init(
        moderationService: HelixModerationService,
        chatMessagesService: HelixChatMessagesService,
        chatSettingsService: HelixChatSettingsService,
        channelStore: ChannelStore
    ) {
        self.moderationService = moderationService
        self.chatMessagesService = chatMessagesService
        self.chatSettingsService = chatSettingsService
        self.channelStore = channelStore
    }
}
