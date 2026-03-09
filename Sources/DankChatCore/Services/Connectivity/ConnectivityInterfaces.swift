import Foundation

public final class IRCWebSocketClient: @unchecked Sendable {
    public var onEvent: (@Sendable (Event) -> Void)?
    
    public enum Event: Sendable {
        case connected
        case disconnected(Error?)
        case message(String)
    }
    
    public init() {}
    
    public func connect(to url: URL) {}
    public func disconnect() {}
    public func send(_ message: String) async {}
}

public struct BackoffPolicy: Sendable {
    public init() {}
    public func delay(for attempt: Int) -> TimeInterval {
        return min(pow(2.0, Double(attempt)), 30.0)
    }
}

public actor IRCCommandRateLimiter {
    public init() {}
    public func acquire() async {}
}

@MainActor
public final class ConnectionStatusStore: ObservableObject {
    public init() {}
    public func update(state: IRCConnectionState) {}
    public func record(_ message: String) {}
}

public final class AppLifecycleMonitor: @unchecked Sendable {
    public enum Event: Sendable {
        case background
        case foreground
    }
    
    public init(handler: @escaping @Sendable (Event) -> Void) {}
    public func start() {}
}

public final class NetworkMonitor: @unchecked Sendable {
    public enum Status: Sendable {
        case satisfied
        case requiresConnection
        case unsatisfied
    }
    
    public init() {}
    
    public func start(handler: @escaping @Sendable (Status) -> Void) {
        // Initially dispatch satisfied stat for stubs to work
        DispatchQueue.global().async {
            handler(.satisfied)
        }
    }
    
    public func stop() {}
}

public actor JoinQueue {
    public init(rateLimiter: IRCCommandRateLimiter, action: @escaping @Sendable (String) async -> Void) {}
    public func enqueue(_ channel: String) async {}
}
