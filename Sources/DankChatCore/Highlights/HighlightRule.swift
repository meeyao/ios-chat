import Combine
import Foundation

/// What a highlight rule matches against.
public enum HighlightKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case username
    case badge
    case message

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .username: return "Username"
        case .badge: return "Badge"
        case .message: return "Message"
        }
    }
}

/// A persisted highlight rule.
public struct HighlightRule: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: HighlightKind
    public var pattern: String
    public var isEnabled: Bool
    public var isCaseSensitive: Bool
    public var isRegex: Bool
    public var createNotification: Bool
    /// Hex color such as `#FF8800`; nil uses the app's default highlight color.
    public var colorHex: String?

    public init(
        id: UUID = UUID(),
        kind: HighlightKind = .message,
        pattern: String = "",
        isEnabled: Bool = true,
        isCaseSensitive: Bool = false,
        isRegex: Bool = false,
        createNotification: Bool = true,
        colorHex: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.pattern = pattern
        self.isEnabled = isEnabled
        self.isCaseSensitive = isCaseSensitive
        self.isRegex = isRegex
        self.createNotification = createNotification
        self.colorHex = colorHex
    }

    public func matches(_ message: ChatMessage) -> Bool {
        let needle = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnabled, !needle.isEmpty else { return false }

        switch kind {
        case .username:
            return equals(message.user.login, needle) || equals(message.user.displayName, needle)
        case .badge:
            return message.badgeTags.contains {
                equals($0.id, needle) || equals("\($0.id)/\($0.version)", needle)
            }
        case .message:
            return isRegex ? matchesRegex(message.text) : matchesWord(message.text, needle: needle)
        }
    }

    private func equals(_ value: String, _ needle: String) -> Bool {
        value.compare(needle, options: isCaseSensitive ? [] : [.caseInsensitive]) == .orderedSame
    }

    private func matchesRegex(_ text: String) -> Bool {
        let options: NSRegularExpression.Options = isCaseSensitive ? [] : [.caseInsensitive]
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return false
        }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private func matchesWord(_ text: String, needle: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: needle)
        let options: NSRegularExpression.Options = isCaseSensitive ? [] : [.caseInsensitive]
        let pattern = "(?<![\\p{L}\\p{N}_])\(escaped)(?![\\p{L}\\p{N}_])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return false
        }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }
}

/// Persists highlight rules and resolves the first matching rule for a message.
@MainActor
public final class HighlightStore: ObservableObject {
    @Published public private(set) var rules: [HighlightRule] = []

    private let defaults: UserDefaults
    private let storageKey = "highlights.rules.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    @discardableResult
    public func addRule(kind: HighlightKind = .message) -> HighlightRule {
        let rule = HighlightRule(kind: kind)
        rules.append(rule)
        save()
        return rule
    }

    public func update(_ rule: HighlightRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[index] = rule
        save()
    }

    public func remove(id: UUID) {
        rules.removeAll { $0.id == id }
        save()
    }

    public func match(for message: ChatMessage) -> HighlightRule? {
        rules.first { $0.matches(message) }
    }

    public func match(for event: ChatEvent) -> HighlightRule? {
        guard case .message(let message) = event else { return nil }
        return match(for: message)
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([HighlightRule].self, from: data)
        else { return }
        rules = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
