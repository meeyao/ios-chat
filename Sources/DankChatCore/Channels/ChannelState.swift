import Foundation

public struct ChannelState: Equatable {
    public var unreadCount: Int
    public var mentionCount: Int
    public var isAtBottom: Bool
    public var lastReadMessageId: String?
    public var connectionState: IRCConnectionState
    /// The latest room state derived from IRC ROOMSTATE tags for this channel.
    public var roomState: RoomState

    public init(
        unreadCount: Int = 0,
        mentionCount: Int = 0,
        isAtBottom: Bool = true,
        lastReadMessageId: String? = nil,
        connectionState: IRCConnectionState = .disconnected(reason: nil),
        roomState: RoomState = RoomState()
    ) {
        self.unreadCount = unreadCount
        self.mentionCount = mentionCount
        self.isAtBottom = isAtBottom
        self.lastReadMessageId = lastReadMessageId
        self.connectionState = connectionState
        self.roomState = roomState
    }
}
