import Foundation

public struct ChannelState: Equatable {
    public var unreadCount: Int
    public var mentionCount: Int
    public var isAtBottom: Bool
    public var lastReadMessageId: String?
    public var connectionState: IRCConnectionState

    public init(
        unreadCount: Int = 0,
        mentionCount: Int = 0,
        isAtBottom: Bool = true,
        lastReadMessageId: String? = nil,
        connectionState: IRCConnectionState = .disconnected(reason: nil)
    ) {
        self.unreadCount = unreadCount
        self.mentionCount = mentionCount
        self.isAtBottom = isAtBottom
        self.lastReadMessageId = lastReadMessageId
        self.connectionState = connectionState
    }
}
