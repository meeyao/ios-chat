import Foundation

/// Minimal EventSub WebSocket client for receiving real-time Twitch events.
///
/// Connects to the Twitch EventSub WebSocket endpoint, handles session lifecycle
/// (welcome, keepalive, reconnect), and forwards event notifications to a
/// caller-provided closure.
///
/// Currently scoped to `user.whisper.message` events only.
public final class EventSubClient: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {

    // MARK: - Public Types

    /// Events surfaced to the caller.
    public enum Event: Sendable {
        case connected(sessionId: String)
        case whisperReceived(WhisperEvent)
        case disconnected(Error?)
    }

    // MARK: - Public Properties

    /// Callback invoked on each EventSub event.
    /// Called on an arbitrary background queue.
    public var onEvent: (@Sendable (Event) -> Void)?

    // MARK: - Private State

    private let helixClient: HelixAPIClient
    private let sessionConfiguration: URLSessionConfiguration
    private lazy var urlSession: URLSession = URLSession(
        configuration: sessionConfiguration,
        delegate: self,
        delegateQueue: nil
    )

    private var webSocketTask: URLSessionWebSocketTask?
    private var sessionId: String?
    private var currentUserId: String?

    /// The default Twitch EventSub WebSocket URL.
    private static let defaultURL = URL(string: "wss://eventsub.wss.twitch.tv/ws")!

    // MARK: - Init

    /// Creates a new EventSub client.
    ///
    /// - Parameters:
    ///   - helixClient: A `HelixAPIClient` used to create EventSub subscriptions via Helix.
    ///   - configuration: URL session configuration. Defaults to `.default`.
    public init(
        helixClient: HelixAPIClient,
        configuration: URLSessionConfiguration = .default
    ) {
        self.helixClient = helixClient
        self.sessionConfiguration = configuration
        super.init()
    }

    // MARK: - Connection

    /// Opens the EventSub WebSocket connection.
    ///
    /// On receiving the `session_welcome` message, emits `.connected(sessionId:)`.
    /// If already connected, disconnects first.
    public func connect() {
        disconnect()
        let task = urlSession.webSocketTask(with: Self.defaultURL)
        self.webSocketTask = task
        task.resume()
        receiveLoop()
    }

    /// Connects and subscribes to whisper events for the given user ID.
    ///
    /// Convenience method that stores the user ID, connects, and auto-subscribes
    /// once the session welcome is received.
    ///
    /// - Parameter userId: The Twitch user ID to subscribe whispers for.
    public func connectAndSubscribeToWhispers(userId: String) {
        self.currentUserId = userId
        connect()
    }

    /// Disconnects the WebSocket and clears session state.
    public func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        sessionId = nil
    }

    // MARK: - Subscriptions

    /// Creates an EventSub subscription for `user.whisper.message`.
    ///
    /// Requires a valid session ID (obtained from `session_welcome`).
    ///
    /// - Parameter userId: The Twitch user ID to receive whispers for.
    /// - Throws: `HelixError` on failure.
    public func subscribeToWhispers(userId: String) async throws {
        guard let sessionId else { return }

        let body = EventSubCreateSubscriptionRequest(
            type: "user.whisper.message",
            version: "1",
            condition: ["user_id": userId],
            transport: .init(method: "websocket", sessionId: sessionId)
        )

        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(body)

        let request = HelixRequest(
            method: "POST",
            path: "/eventsub/subscriptions",
            body: bodyData,
            requiredScopes: [HelixScope.userManageWhispers]
        )

        let _: EventSubCreateSubscriptionResponse = try await helixClient.execute(request)
    }

    // MARK: - URLSessionWebSocketDelegate

    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        // Connection opened; session_welcome will arrive as a message.
    }

    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        onEvent?(.disconnected(nil))
    }

    // MARK: - Private

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.onEvent?(.disconnected(error))
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self.receiveLoop()
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let message = try? decoder.decode(EventSubMessage.self, from: data) else { return }

        switch message.metadata.messageType {
        case "session_welcome":
            handleSessionWelcome(message)

        case "session_reconnect":
            handleSessionReconnect(message)

        case "notification":
            handleNotification(message)

        case "session_keepalive":
            // Keepalive - no action needed.
            break

        case "revocation":
            // Subscription revoked - could re-subscribe.
            break

        default:
            break
        }
    }

    private func handleSessionWelcome(_ message: EventSubMessage) {
        guard let session = message.payload.session else { return }
        self.sessionId = session.id
        onEvent?(.connected(sessionId: session.id))

        // Auto-subscribe if a user ID was provided via connectAndSubscribeToWhispers.
        if let userId = currentUserId {
            Task {
                try? await subscribeToWhispers(userId: userId)
            }
        }
    }

    private func handleSessionReconnect(_ message: EventSubMessage) {
        guard let session = message.payload.session,
              let reconnectUrlString = session.reconnectUrl,
              let reconnectUrl = URL(string: reconnectUrlString) else { return }

        // Connect to the new URL before closing the old connection.
        let oldTask = webSocketTask
        let newTask = urlSession.webSocketTask(with: reconnectUrl)
        self.webSocketTask = newTask
        newTask.resume()
        receiveLoop()

        // Close old connection after new one is established.
        oldTask?.cancel(with: .goingAway, reason: nil)
    }

    private func handleNotification(_ message: EventSubMessage) {
        guard let subscriptionType = message.metadata.subscriptionType else { return }

        switch subscriptionType {
        case "user.whisper.message":
            if let event = message.payload.event {
                onEvent?(.whisperReceived(event))
            }

        default:
            break
        }
    }
}
