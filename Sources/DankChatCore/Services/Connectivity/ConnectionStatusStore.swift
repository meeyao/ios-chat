import Combine
import Foundation

public struct ConnectionEvent: Identifiable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let message: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), message: String) {
        self.id = id
        self.timestamp = timestamp
        self.message = message
    }
}

@MainActor
public final class ConnectionStatusStore: ObservableObject {
    @Published public private(set) var state: IRCConnectionState = .disconnected(reason: nil)
    @Published public private(set) var events: [ConnectionEvent] = []

    public init() {}

    public func update(state: IRCConnectionState) {
        self.state = state
    }

    public func record(_ message: String) {
        events.insert(ConnectionEvent(message: message), at: 0)
        if events.count > 100 {
            events.removeLast(events.count - 100)
        }
    }
}
