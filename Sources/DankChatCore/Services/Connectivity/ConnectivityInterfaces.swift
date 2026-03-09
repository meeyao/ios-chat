import Foundation

@available(macOS 12.0, iOS 15.0, *)
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

@available(macOS 12.0, iOS 15.0, *)
public actor IRCCommandRateLimiter {
    public init() {}
    public func acquire() async {}
}

@available(macOS 12.0, iOS 15.0, *)
@MainActor
public final class ConnectionStatusStore: ObservableObject {
    public enum Status: String, CustomStringConvertible, Sendable {
        case disconnected
        case connecting
        case connected

        public var description: String {
            rawValue.capitalized
        }
    }

    @Published public private(set) var status: Status = .disconnected
    @Published public private(set) var state: IRCConnectionState = .disconnected(reason: nil)
    @Published public private(set) var logs: [String] = []

    public init() {}

    public func update(state: IRCConnectionState) {
        self.state = state
        switch state {
        case .connected:
            self.status = .connected
        case .connecting, .reconnecting:
            self.status = .connecting
        case .disconnected:
            self.status = .disconnected
        }
    }

    public func record(_ message: String) {
        logs.append("[\(Date())] \(message)")
        if logs.count > 100 {
            logs.removeFirst()
        }
    }
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

@available(macOS 12.0, iOS 15.0, *)
public actor JoinQueue {
    public init(rateLimiter: IRCCommandRateLimiter, action: @escaping @Sendable (String) async -> Void) {}
    public func enqueue(_ channel: String) async {}
}
