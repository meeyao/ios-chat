import Foundation

/// Expands outgoing messages that match a custom command trigger.
///
/// If the user types `/hello` and a custom command named `hello` exists, the
/// resolver replaces the message text with the command's template, expanding
/// `{channel}` and `{user}` placeholders. Messages that do not match any
/// command pass through unchanged.
public struct CommandResolver: Sendable {
    public init() {}

    /// Context values available for placeholder expansion.
    public struct Context: Sendable {
        public let channel: String
        public let user: String

        public init(channel: String, user: String) {
            self.channel = channel
            self.user = user
        }
    }

    /// Resolves the given message text against the provided commands.
    ///
    /// - Parameters:
    ///   - text: The raw message text (trimmed).
    ///   - commands: The user's custom commands.
    ///   - context: Placeholder values for `{channel}` and `{user}`.
    /// - Returns: The expanded message if a command matched, or the original text.
    public func resolve(
        text: String,
        commands: [CustomCommand],
        context: Context
    ) -> String {
        guard text.hasPrefix("/") else { return text }

        // Extract the command name (first "word" after the slash).
        let afterSlash = String(text.dropFirst())
        let parts = afterSlash.split(separator: " ", maxSplits: 1)
        guard let trigger = parts.first else { return text }

        let triggerLower = trigger.lowercased()
        guard let command = commands.first(where: { $0.name.lowercased() == triggerLower }) else {
            return text
        }

        var expanded = command.template
        expanded = expanded.replacingOccurrences(of: "{channel}", with: context.channel)
        expanded = expanded.replacingOccurrences(of: "{user}", with: context.user)

        // Append any trailing arguments the user typed after the command trigger.
        if parts.count > 1, let args = parts.last {
            expanded = expanded.replacingOccurrences(of: "{args}", with: String(args))
        } else {
            expanded = expanded.replacingOccurrences(of: "{args}", with: "")
        }

        return expanded.trimmingCharacters(in: .whitespaces)
    }
}
