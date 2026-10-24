import Foundation
#if canImport(UIKit)
import UIKit
#endif

public final class AppLifecycleMonitor {
    public enum Event: Equatable {
        case foreground
        case background
    }

    private var observerTokens: [NSObjectProtocol] = []
    private let handler: (Event) -> Void

    public init(handler: @escaping (Event) -> Void) {
        self.handler = handler
    }

    public func start() {
        #if canImport(UIKit)
        let center = NotificationCenter.default
        observerTokens.append(center.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handler(.foreground)
        })
        observerTokens.append(center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handler(.background)
        })
        #endif
    }

    public func stop() {
        let center = NotificationCenter.default
        observerTokens.forEach { center.removeObserver($0) }
        observerTokens.removeAll()
    }
}
