import Foundation

public enum IRCConnectionState: Equatable {
    case disconnected(reason: String?)
    case connecting
    case connected
    case reconnecting(attempt: Int)
}
