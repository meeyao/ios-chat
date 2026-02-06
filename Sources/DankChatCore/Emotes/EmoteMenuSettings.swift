import Foundation

@MainActor
public final class EmoteMenuSettings: ObservableObject {
    public enum RecentsOrdering: String, CaseIterable, Codable {
        case mostRecent
        case mostUsed

        public var displayName: String {
            switch self {
            case .mostRecent:
                return "Most Recent"
            case .mostUsed:
                return "Most Used"
            }
        }
    }

    @Published public var recentsOrdering: RecentsOrdering {
        didSet {
            persist()
        }
    }

    private let storage: UserDefaults
    private let orderingKey = "emoteMenu.recentsOrdering"

    public init(storage: UserDefaults = .standard) {
        self.storage = storage
        if let rawValue = storage.string(forKey: orderingKey),
           let ordering = RecentsOrdering(rawValue: rawValue) {
            self.recentsOrdering = ordering
        } else {
            self.recentsOrdering = .mostRecent
        }
    }

    private func persist() {
        storage.set(recentsOrdering.rawValue, forKey: orderingKey)
    }
}
