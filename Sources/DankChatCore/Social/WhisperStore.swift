import Combine
import Foundation

// MARK: - Whisper Message Model

/// A single whisper message in a conversation.
public struct WhisperMessage: Identifiable, Equatable {
    /// Unique message identifier (whisper ID for received, UUID for sent).
    public let id: String
    /// The user ID of the message author.
    public let fromUserId: String
    /// The login of the message author.
    public let fromUserLogin: String
    /// The display name of the message author.
    public let fromUserName: String
    /// The whisper text body.
    public let text: String
    /// When the message was created or received.
    public let timestamp: Date
    /// Whether this message was sent by the local user.
    public let isOutgoing: Bool
    /// Delivery status for outgoing messages.
    public let deliveryState: DeliveryState

    public enum DeliveryState: String, Equatable {
        /// Successfully sent to the Helix API. Delivery to recipient is not guaranteed.
        case sent
        /// Failed to send via the Helix API.
        case failed
        /// Received from EventSub (incoming message).
        case received
    }

    public init(
        id: String,
        fromUserId: String,
        fromUserLogin: String,
        fromUserName: String,
        text: String,
        timestamp: Date,
        isOutgoing: Bool,
        deliveryState: DeliveryState
    ) {
        self.id = id
        self.fromUserId = fromUserId
        self.fromUserLogin = fromUserLogin
        self.fromUserName = fromUserName
        self.text = text
        self.timestamp = timestamp
        self.isOutgoing = isOutgoing
        self.deliveryState = deliveryState
    }
}

// MARK: - Whisper Conversation Model

/// A conversation with a single other user, containing ordered whisper messages.
public struct WhisperConversation: Identifiable, Equatable {
    /// The other user's ID (conversation key).
    public let id: String
    /// The other user's login name.
    public let userLogin: String
    /// The other user's display name.
    public let userName: String
    /// Messages in chronological order.
    public var messages: [WhisperMessage]
    /// Timestamp of the most recent message (for sorting conversations).
    public var lastActivity: Date

    public init(id: String, userLogin: String, userName: String, messages: [WhisperMessage] = [], lastActivity: Date = .distantPast) {
        self.id = id
        self.userLogin = userLogin
        self.userName = userName
        self.messages = messages
        self.lastActivity = lastActivity
    }
}

// MARK: - Whisper Store

/// Observable store managing whisper conversations.
///
/// Receives incoming whispers from an `EventSubClient` callback and sends
/// outgoing whispers via `HelixWhisperService`. Maintains conversations keyed
/// by the other user's ID.
///
/// Outgoing messages are recorded with a `sent` delivery state to communicate
/// that the Helix API accepted the request but delivery is not guaranteed.
@MainActor
public final class WhisperStore: ObservableObject {
    /// All conversations sorted by most recent activity.
    @Published public private(set) var conversations: [WhisperConversation] = []

    private let whisperService: HelixWhisperService
    private let eventSubClient: EventSubClient

    /// The authenticated user's ID, set when connecting.
    private var currentUserId: String?
    private var currentUserLogin: String?
    private var currentUserName: String?

    /// Maximum messages per conversation to prevent unbounded growth.
    private let maxMessagesPerConversation: Int

    /// Creates a new whisper store.
    ///
    /// - Parameters:
    ///   - whisperService: The Helix whisper service for sending whispers.
    ///   - eventSubClient: The EventSub client for receiving whispers.
    ///   - maxMessagesPerConversation: Maximum messages retained per conversation. Defaults to 500.
    public init(
        whisperService: HelixWhisperService,
        eventSubClient: EventSubClient,
        maxMessagesPerConversation: Int = 500
    ) {
        self.whisperService = whisperService
        self.eventSubClient = eventSubClient
        self.maxMessagesPerConversation = maxMessagesPerConversation
    }

    /// Starts the EventSub client and subscribes to whisper events for the given user.
    ///
    /// - Parameters:
    ///   - userId: The authenticated user's Twitch ID.
    ///   - userLogin: The authenticated user's login name.
    ///   - userName: The authenticated user's display name.
    public func start(userId: String, userLogin: String, userName: String) {
        self.currentUserId = userId
        self.currentUserLogin = userLogin
        self.currentUserName = userName

        eventSubClient.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleEventSubEvent(event)
            }
        }

        eventSubClient.connectAndSubscribeToWhispers(userId: userId)
    }

    /// Stops the EventSub client and clears the current user identity.
    public func stop() {
        eventSubClient.disconnect()
        eventSubClient.onEvent = nil
        currentUserId = nil
        currentUserLogin = nil
        currentUserName = nil
    }

    /// Clears all conversations.
    public func clearAll() {
        conversations.removeAll()
    }

    /// Sends a whisper to the specified user.
    ///
    /// Creates a local outgoing message immediately and attempts to send via Helix.
    /// On failure, the message delivery state is updated to `.failed`.
    ///
    /// - Parameters:
    ///   - toUserId: The recipient's Twitch user ID.
    ///   - toUserLogin: The recipient's login name.
    ///   - toUserName: The recipient's display name.
    ///   - text: The whisper message text.
    public func sendWhisper(toUserId: String, toUserLogin: String, toUserName: String, text: String) async {
        guard let currentUserId, let currentUserLogin, let currentUserName else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let messageId = UUID().uuidString
        let now = Date()

        let outgoing = WhisperMessage(
            id: messageId,
            fromUserId: currentUserId,
            fromUserLogin: currentUserLogin,
            fromUserName: currentUserName,
            text: trimmed,
            timestamp: now,
            isOutgoing: true,
            deliveryState: .sent
        )

        appendMessage(outgoing, otherUserId: toUserId, otherUserLogin: toUserLogin, otherUserName: toUserName)

        do {
            try await whisperService.sendWhisper(fromUserId: currentUserId, toUserId: toUserId, message: trimmed)
        } catch {
            // Mark message as failed.
            markMessageFailed(messageId: messageId, conversationUserId: toUserId)
        }
    }

    // MARK: - Private

    private func handleEventSubEvent(_ event: EventSubClient.Event) {
        switch event {
        case .whisperReceived(let whisperEvent):
            handleIncomingWhisper(whisperEvent)
        case .connected, .disconnected:
            break
        }
    }

    private func handleIncomingWhisper(_ whisperEvent: WhisperEvent) {
        let message = WhisperMessage(
            id: whisperEvent.whisperId,
            fromUserId: whisperEvent.fromUserId,
            fromUserLogin: whisperEvent.fromUserLogin,
            fromUserName: whisperEvent.fromUserName,
            text: whisperEvent.whisper.text,
            timestamp: Date(),
            isOutgoing: false,
            deliveryState: .received
        )

        appendMessage(
            message,
            otherUserId: whisperEvent.fromUserId,
            otherUserLogin: whisperEvent.fromUserLogin,
            otherUserName: whisperEvent.fromUserName
        )
    }

    private func appendMessage(_ message: WhisperMessage, otherUserId: String, otherUserLogin: String, otherUserName: String) {
        if let index = conversations.firstIndex(where: { $0.id == otherUserId }) {
            conversations[index].messages.append(message)
            conversations[index].lastActivity = message.timestamp

            // Trim if over limit.
            if conversations[index].messages.count > maxMessagesPerConversation {
                let overflow = conversations[index].messages.count - maxMessagesPerConversation
                conversations[index].messages.removeFirst(overflow)
            }
        } else {
            let conversation = WhisperConversation(
                id: otherUserId,
                userLogin: otherUserLogin,
                userName: otherUserName,
                messages: [message],
                lastActivity: message.timestamp
            )
            conversations.append(conversation)
        }

        // Sort conversations by most recent activity.
        conversations.sort { $0.lastActivity > $1.lastActivity }
    }

    private func markMessageFailed(messageId: String, conversationUserId: String) {
        guard let convIndex = conversations.firstIndex(where: { $0.id == conversationUserId }),
              let msgIndex = conversations[convIndex].messages.firstIndex(where: { $0.id == messageId })
        else { return }

        let old = conversations[convIndex].messages[msgIndex]
        conversations[convIndex].messages[msgIndex] = WhisperMessage(
            id: old.id,
            fromUserId: old.fromUserId,
            fromUserLogin: old.fromUserLogin,
            fromUserName: old.fromUserName,
            text: old.text,
            timestamp: old.timestamp,
            isOutgoing: old.isOutgoing,
            deliveryState: .failed
        )
    }
}
