import Combine
import Foundation

/// Observable store that maintains separate chat stores for mentions and replies.
///
/// Incoming events are classified using `SocialMessageClassifier` and appended to
/// the appropriate store. Feature tabs (Mentions, Replies) bind directly to the
/// published chat stores.
@available(macOS 12.0, iOS 15.0, *)
@MainActor
public final class SocialTabStore: ObservableObject {
    /// Chat store containing messages that mention the current user.
    @Published public private(set) var mentionsStore: ChatStore
    /// Chat store containing reply messages targeting the current user.
    @Published public private(set) var repliesStore: ChatStore

    private let classifier: SocialMessageClassifier

    /// Creates a new social tab store.
    ///
    /// - Parameter settings: Chat settings used for scrollback limits in the backing stores.
    public init(settings: ChatSettings) {
        self.classifier = SocialMessageClassifier()
        self.mentionsStore = ChatStore(settings: settings)
        self.repliesStore = ChatStore(settings: settings)
    }

    /// Classifies the event and appends it to the mentions and/or replies store
    /// as appropriate.
    ///
    /// - Parameters:
    ///   - event: The incoming chat event.
    ///   - identity: The authenticated user's identity, or `nil` if signed out.
    public func append(event: ChatEvent, identity: HelixUser?) {
        guard case .message(let message) = event else { return }

        if classifier.isMention(message: message, identity: identity) {
            mentionsStore.append(event: event)
        }

        if classifier.isReply(message: message, identity: identity) {
            repliesStore.append(event: event)
        }
    }

    /// Clears both mentions and replies stores.
    public func clear() {
        mentionsStore.clear()
        repliesStore.clear()
    }
}
