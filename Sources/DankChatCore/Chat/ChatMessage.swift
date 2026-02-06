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
        badgeTags: [TwitchBadgeTag] = []
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
    }
}
