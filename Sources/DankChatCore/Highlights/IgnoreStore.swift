import Combine
import Foundation

/// A persisted user ignore rule. Ignored users are hidden from timelines.
public struct IgnoreRule: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var pattern: String
    public var isEnabled: Bool
    public var isRegex: Bool

    public init(
        id: UUID = UUID(),
        pattern: String = "",
        isEnabled: Bool = true,
        isRegex: Bool = false
    ) {
        self.id = id
        self.pattern = pattern
        self.isEnabled = isEnabled
        self.isRegex = isRegex
    }

    public func matches(login: String, displayName: String) -> Bool {
        let needle = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnabled, !needle.isEmpty else { return false }
        if isRegex {
            guard let regex = try? NSRegularExpression(pattern: needle, options: [.caseInsensitive]) else {
                return false
            }
            return [login, displayName].contains { value in
                regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
            }
        }
        return login.compare(needle, options: [.caseInsensitive]) == .orderedSame
            || displayName.compare(needle, options: [.caseInsensitive]) == .orderedSame
    }
}

/// Persists ignored-user rules and answers whether a message should be hidden.
@MainActor
public final class IgnoreStore: ObservableObject {
    @Published public private(set) var rules: [IgnoreRule] = []

    private let defaults: UserDefaults
    private let storageKey = "ignores.rules.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    @discardableResult
    public func addRule() -> IgnoreRule {
        let rule = IgnoreRule()
        rules.append(rule)
        save()
        return rule
    }

    public func update(_ rule: IgnoreRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[index] = rule
        save()
    }

    public func remove(id: UUID) {
        rules.removeAll { $0.id == id }
        save()
    }

    public func isIgnored(_ message: ChatMessage) -> Bool {
        isIgnored(login: message.user.login, displayName: message.user.displayName)
    }

    public func isIgnored(login: String, displayName: String? = nil) -> Bool {
        rules.contains { $0.matches(login: login, displayName: displayName ?? login) }
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([IgnoreRule].self, from: data)
        else { return }
        rules = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
