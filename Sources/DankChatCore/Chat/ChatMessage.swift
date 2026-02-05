import Foundation

public struct ChatMessage: Equatable {
    public let id: String?
    public let user: ChatUser
    public let text: String
    public let timestamp: Date
    public let receivedAt: Date
    public let latencyMs: Int?
    public let isAction: Bool
    public let channel: String

    public init(
        id: String? = nil,
        user: ChatUser,
        text: String,
        timestamp: Date,
        receivedAt: Date,
        latencyMs: Int? = nil,
        isAction: Bool = false,
        channel: String
    ) {
        self.id = id
        self.user = user
        self.text = text
        self.timestamp = timestamp
        self.receivedAt = receivedAt
        self.latencyMs = latencyMs
        self.isAction = isAction
        self.channel = channel
    }
}
