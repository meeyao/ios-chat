import Combine
import Foundation

public struct ProviderOutageEvent: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let provider: ProviderID
    public let message: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), provider: ProviderID, message: String) {
        self.id = id
        self.timestamp = timestamp
        self.provider = provider
        self.message = message
    }
}

@available(macOS 12.0, iOS 15.0, *)
@MainActor
public final class ProviderStatusStore: ObservableObject {
    @Published public private(set) var outages: [ProviderOutageEvent] = []

    public init() {}

    public func recordOutage(provider: ProviderID, message: String) {
        outages.insert(ProviderOutageEvent(provider: provider, message: message), at: 0)
        if outages.count > 100 {
            outages.removeLast(outages.count - 100)
        }
    }
}
