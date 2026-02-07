import Foundation

// MARK: - WebSocket Frame Envelope

/// Top-level envelope for every EventSub WebSocket message.
public struct EventSubMessage: Decodable {
    public let metadata: Metadata
    public let payload: Payload

    public struct Metadata: Decodable {
        public let messageId: String
        public let messageType: String
        public let messageTimestamp: String
        public let subscriptionType: String?
    }

    public struct Payload: Decodable {
        public let session: SessionPayload?
        public let subscription: SubscriptionPayload?
        public let event: WhisperEvent?
    }
}

// MARK: - Session

/// Payload delivered by `session_welcome` and `session_reconnect` messages.
public struct SessionPayload: Decodable {
    public let id: String
    public let status: String?
    public let keepaliveTimeoutSeconds: Int?
    public let reconnectUrl: String?
}

// MARK: - Subscription

/// Subscription descriptor echoed back in notification payloads.
public struct SubscriptionPayload: Decodable {
    public let id: String
    public let type: String
    public let status: String?
}

// MARK: - Whisper Event

/// The `event` object for a `user.whisper.message` notification.
public struct WhisperEvent: Decodable {
    /// The user ID of the whisper sender.
    public let fromUserId: String
    /// The login name of the whisper sender.
    public let fromUserLogin: String
    /// The display name of the whisper sender.
    public let fromUserName: String
    /// The user ID of the whisper recipient.
    public let toUserId: String
    /// The login name of the whisper recipient.
    public let toUserLogin: String
    /// The display name of the whisper recipient.
    public let toUserName: String
    /// The whisper ID.
    public let whisperId: String
    /// The whisper payload containing the message text.
    public let whisper: WhisperBody

    public struct WhisperBody: Decodable {
        /// The whisper text.
        public let text: String
    }
}

// MARK: - EventSub Create Subscription Request/Response

/// Request body for `POST /eventsub/subscriptions`.
struct EventSubCreateSubscriptionRequest: Encodable {
    let type: String
    let version: String
    let condition: [String: String]
    let transport: Transport

    struct Transport: Encodable {
        let method: String
        let sessionId: String

        enum CodingKeys: String, CodingKey {
            case method
            case sessionId = "session_id"
        }
    }

    enum CodingKeys: String, CodingKey {
        case type, version, condition, transport
    }
}

/// Response from `POST /eventsub/subscriptions`.
struct EventSubCreateSubscriptionResponse: Decodable {
    let data: [SubscriptionPayload]
}
