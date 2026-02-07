import Foundation

public struct TwitchEmoteOccurrence: Equatable {
    public let emoteId: String
    public let range: NSRange

    public init(emoteId: String, range: NSRange) {
        self.emoteId = emoteId
        self.range = range
    }
}

public struct TwitchBadgeTag: Equatable {
    public let id: String
    public let version: String

    public init(id: String, version: String) {
        self.id = id
        self.version = version
    }
}

/// Metadata for a reply message, populated from IRC `reply-parent-*` tags.
public struct ReplyMetadata: Equatable {
    /// The message ID of the parent message being replied to.
    public let parentMessageId: String
    /// The user ID of the parent message author.
    public let parentUserId: String?
    /// The login name of the parent message author.
    public let parentUserLogin: String?
    /// The display name of the parent message author.
    public let parentDisplayName: String?
    /// The body text of the parent message.
    public let parentMessageBody: String?

    public init(
        parentMessageId: String,
        parentUserId: String? = nil,
        parentUserLogin: String? = nil,
        parentDisplayName: String? = nil,
        parentMessageBody: String? = nil
    ) {
        self.parentMessageId = parentMessageId
        self.parentUserId = parentUserId
        self.parentUserLogin = parentUserLogin
        self.parentDisplayName = parentDisplayName
        self.parentMessageBody = parentMessageBody
    }
}

public struct ChatMessage: Equatable {
    public let id: String?
    public let user: ChatUser
    public let text: String
    public let timestamp: Date
    public let receivedAt: Date
    public let latencyMs: Int?
    public let isAction: Bool
    public let channel: String
    public let twitchEmotes: [TwitchEmoteOccurrence]
    public let badgeTags: [TwitchBadgeTag]
    /// Reply metadata, present only when this message is a reply to another message.
    public let replyMetadata: ReplyMetadata?

    public init(
        id: String? = nil,
        user: ChatUser,
        text: String,
        timestamp: Date,
        receivedAt: Date,
        latencyMs: Int? = nil,
        isAction: Bool = false,
        channel: String,
        twitchEmotes: [TwitchEmoteOccurrence] = [],
        badgeTags: [TwitchBadgeTag] = [],
        replyMetadata: ReplyMetadata? = nil
    ) {
        self.id = id
        self.user = user
        self.text = text
        self.timestamp = timestamp
        self.receivedAt = receivedAt
        self.latencyMs = latencyMs
        self.isAction = isAction
        self.channel = channel
        self.twitchEmotes = twitchEmotes
        self.badgeTags = badgeTags
        self.replyMetadata = replyMetadata
    }
}
