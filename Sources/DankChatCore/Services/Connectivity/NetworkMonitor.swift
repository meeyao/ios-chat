import Foundation
import Network

public final class NetworkMonitor: @unchecked Sendable {
    public enum Status: Equatable, Sendable {
        case satisfied
        case unsatisfied
        case requiresConnection
    }

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var handler: (@Sendable (Status) -> Void)?

    public init() {
        self.monitor = NWPathMonitor()
    }

    public func start(handler: @escaping @Sendable (Status) -> Void) {
        self.handler = handler
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let status: Status
            switch path.status {
            case .satisfied:
                status = .satisfied
            case .requiresConnection:
                status = .requiresConnection
            case .unsatisfied:
                status = .unsatisfied
            @unknown default:
                status = .unsatisfied
            }
            self.handler?(status)
        }
        monitor.start(queue: queue)
    }

    public func stop() {
        monitor.cancel()
        handler = nil
    }
}
