import Combine
import Foundation

@MainActor
public final class BadgeVisibilitySettings: ObservableObject {
    public static let shared = BadgeVisibilitySettings()

    @Published public var isGlobalEnabled: Bool {
        didSet { persistIfNeeded() }
    }
    @Published public var providerVisibility: [ProviderID: Bool] {
        didSet { persistIfNeeded() }
    }
    @Published public var categoryVisibility: [ProviderID: [String: Bool]] {
        didSet { persistIfNeeded() }
    }

    private let storageKey = "badgeVisibilitySettings.v1"
    private let userDefaults: UserDefaults
    private var isHydrating = false

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if let snapshot = Self.loadSnapshot(from: userDefaults, key: storageKey) {
            isHydrating = true
            self.isGlobalEnabled = snapshot.globalEnabled
            self.providerVisibility = snapshot.providers
            self.categoryVisibility = snapshot.categories
            isHydrating = false
        } else {
            self.isGlobalEnabled = true
            self.providerVisibility = Dictionary(uniqueKeysWithValues: ProviderID.allCases.map { ($0, true) })
            self.categoryVisibility = [:]
        }
    }

    public func isBadgeVisible(_ badge: Badge) -> Bool {
        isBadgeVisible(provider: badge.provider, badgeId: badge.badgeId)
    }

    public func isBadgeVisible(provider: ProviderID, badgeId: String) -> Bool {
        guard isGlobalEnabled else { return false }
        guard providerVisibility[provider] ?? true else { return false }
        return categoryVisibility[provider]?[badgeId] ?? true
    }

    public func isProviderVisible(_ provider: ProviderID) -> Bool {
        guard isGlobalEnabled else { return false }
        return providerVisibility[provider] ?? true
    }

    public func setProviderVisibility(_ provider: ProviderID, isVisible: Bool) {
        providerVisibility[provider] = isVisible
    }

    public func setCategoryVisibility(provider: ProviderID, badgeId: String, isVisible: Bool) {
        var categories = categoryVisibility[provider] ?? [:]
        categories[badgeId] = isVisible
        categoryVisibility[provider] = categories
    }

    private func persistIfNeeded() {
        guard !isHydrating else { return }
        persist()
    }

    private func persist() {
        let snapshot = Snapshot(
            globalEnabled: isGlobalEnabled,
            providers: encodeProviders(providerVisibility),
            categories: encodeCategories(categoryVisibility)
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private static func loadSnapshot(from defaults: UserDefaults, key: String) -> DecodedSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return nil }
        let providers = decodeProviders(snapshot.providers)
        let categories = decodeCategories(snapshot.categories)
        return DecodedSnapshot(globalEnabled: snapshot.globalEnabled, providers: providers, categories: categories)
    }

    private func encodeProviders(_ providers: [ProviderID: Bool]) -> [String: Bool] {
        Dictionary(uniqueKeysWithValues: providers.map { ($0.key.rawValue, $0.value) })
    }

    private func encodeCategories(_ categories: [ProviderID: [String: Bool]]) -> [String: [String: Bool]] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.key.rawValue, $0.value) })
    }

    private static func decodeProviders(_ providers: [String: Bool]) -> [ProviderID: Bool] {
        Dictionary(uniqueKeysWithValues: providers.compactMap { key, value in
            guard let provider = ProviderID(rawValue: key) else { return nil }
            return (provider, value)
        })
    }

    private static func decodeCategories(_ categories: [String: [String: Bool]]) -> [ProviderID: [String: Bool]] {
        Dictionary(uniqueKeysWithValues: categories.compactMap { key, value in
            guard let provider = ProviderID(rawValue: key) else { return nil }
            return (provider, value)
        })
    }
}

private struct Snapshot: Codable {
    let globalEnabled: Bool
    let providers: [String: Bool]
    let categories: [String: [String: Bool]]

    init(
        globalEnabled: Bool,
        providers: [String: Bool],
        categories: [String: [String: Bool]]
    ) {
        self.globalEnabled = globalEnabled
        self.providers = providers
        self.categories = categories
    }
}

private struct DecodedSnapshot {
    let globalEnabled: Bool
    let providers: [ProviderID: Bool]
    let categories: [ProviderID: [String: Bool]]
}
