import Foundation

/// Classifies incoming chat messages as mentions or replies for the signed-in user.
///
/// Uses the authenticated user's identity (login and display name) to determine
/// whether a message mentions or replies to the current user.
public struct SocialMessageClassifier {
    public init() {}

    /// Returns `true` when `message.text` contains the signed-in user's login or
    /// display name (case-insensitive). Returns `false` if identity is `nil`.
    public func isMention(message: ChatMessage, identity: HelixUser?) -> Bool {
        guard let identity else { return false }
        let tokens = [identity.login, identity.displayName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return false }
        let lowerText = message.text.lowercased()
        return tokens.contains { lowerText.contains($0.lowercased()) }
    }

    /// Returns `true` when the message has reply metadata that targets the
    /// signed-in user (by user ID, login, or display name).
    /// Returns `false` if identity is `nil` or if the message has no reply metadata.
    public func isReply(message: ChatMessage, identity: HelixUser?) -> Bool {
        guard let identity, let reply = message.replyMetadata else { return false }

        // Check by user ID first (most reliable).
        if let parentUserId = reply.parentUserId, !parentUserId.isEmpty {
            if parentUserId == identity.id {
                return true
            }
        }

        // Fall back to login comparison.
        if let parentLogin = reply.parentUserLogin, !parentLogin.isEmpty {
            if parentLogin.lowercased() == identity.login.lowercased() {
                return true
            }
        }

        // Fall back to display name comparison.
        if let parentDisplayName = reply.parentDisplayName, !parentDisplayName.isEmpty {
            if parentDisplayName.lowercased() == identity.displayName.lowercased() {
                return true
            }
        }

        return false
    }
}
