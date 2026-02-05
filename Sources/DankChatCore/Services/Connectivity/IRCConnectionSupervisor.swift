import Foundation

public final class IRCConnectionSupervisor: @unchecked Sendable {
    private let client: IRCWebSocketClient
    private let backoffPolicy: BackoffPolicy
    private let rateLimiter: IRCCommandRateLimiter
    private let statusStore: ConnectionStatusStore
    private let networkMonitor: NetworkMonitor
    private let lifecycleMonitor: AppLifecycleMonitor
    private let queue = DispatchQueue(label: "IRCConnectionSupervisor")

    public var onMessage: (@Sendable (String) -> Void)?

    private var configuration: IRCConfiguration?
    private var joinQueue: JoinQueue?
    private var lastChannels: Set<String> = []
    private var reconnectAttempt = 0
    private var shouldReconnect = false
    private var isSuspended = false
    private var isNetworkAvailable = true

    public init(
        client: IRCWebSocketClient = IRCWebSocketClient(),
        backoffPolicy: BackoffPolicy = BackoffPolicy(),
        rateLimiter: IRCCommandRateLimiter = IRCCommandRateLimiter(),
        statusStore: ConnectionStatusStore = ConnectionStatusStore(),
        networkMonitor: NetworkMonitor = NetworkMonitor()
    ) {
        self.client = client
        self.backoffPolicy = backoffPolicy
        self.rateLimiter = rateLimiter
        self.statusStore = statusStore
        self.networkMonitor = networkMonitor
        self.lifecycleMonitor = AppLifecycleMonitor { [weak self] event in
            self?.handleLifecycle(event: event)
        }
        self.client.onEvent = { [weak self] event in
            self?.handle(event: event)
        }
        self.lifecycleMonitor.start()
    }

    public func startMonitoring() {
        networkMonitor.start { [weak self] status in
            self?.handleNetwork(status: status)
        }
    }

    public func stopMonitoring() {
        networkMonitor.stop()
    }

    public func connect(configuration: IRCConfiguration, channels: [String]) {
        self.configuration = configuration
        self.lastChannels = Set(channels.map { $0.lowercased() })
        self.joinQueue = JoinQueue(rateLimiter: rateLimiter) { [weak self] channel in
            await self?.sendJoin(channel)
        }
        shouldReconnect = true
        reconnectAttempt = 0
        connectWebSocket()
    }

    public func disconnect(reason: String? = nil) {
        shouldReconnect = false
        reconnectAttempt = 0
        client.disconnect()
        Task { @MainActor in
            statusStore.update(state: .disconnected(reason: reason))
            if let reason {
                statusStore.record("Disconnected: \(reason)")
            } else {
                statusStore.record("Disconnected")
            }
        }
    }

    public func enqueueJoin(_ channel: String) {
        lastChannels.insert(channel.lowercased())
        Task { await joinQueue?.enqueue(channel) }
    }

    public func sendRaw(_ message: String) {
        Task {
            await rateLimiter.acquire()
            await client.send(message)
        }
    }

    public func statusStore() -> ConnectionStatusStore {
        statusStore
    }

    private func connectWebSocket() {
        guard let configuration else { return }
        guard !isSuspended else { return }
        guard isNetworkAvailable else { return }
        Task { @MainActor in
            statusStore.update(state: reconnectAttempt == 0 ? .connecting : .reconnecting(attempt: reconnectAttempt))
            statusStore.record("Connecting to IRC")
        }
        client.connect(to: configuration.endpoint)
        Task { await authenticateAndJoin(configuration: configuration) }
    }

    private func authenticateAndJoin(configuration: IRCConfiguration) async {
        await client.send("CAP REQ :twitch.tv/membership twitch.tv/tags twitch.tv/commands")
        await client.send("PASS oauth:\(configuration.oauthToken)")
        await client.send("NICK \(configuration.nickname)")
        await client.send("USER \(configuration.user) 8 * :\(configuration.user)")
        await joinLastChannels()
    }

    private func sendJoin(_ channel: String) async {
        await client.send("JOIN #\(channel)")
        Task { @MainActor in
            statusStore.record("JOIN #\(channel)")
        }
    }

    private func joinLastChannels() async {
        for channel in lastChannels.sorted() {
            await joinQueue?.enqueue(channel)
        }
    }

    private func handle(event: IRCWebSocketClient.Event) {
        switch event {
        case .connected:
            Task { @MainActor in
                statusStore.update(state: .connected)
                statusStore.record("IRC connected")
            }
            reconnectAttempt = 0
        case .disconnected(let error):
            Task { @MainActor in
                statusStore.update(state: .disconnected(reason: error?.localizedDescription))
                statusStore.record("IRC disconnected")
            }
            scheduleReconnectIfNeeded()
        case .message(let text):
            onMessage?(text)
        }
    }

    private func scheduleReconnectIfNeeded() {
        guard shouldReconnect, !isSuspended, isNetworkAvailable else { return }
        reconnectAttempt += 1
        let delay = backoffPolicy.delay(for: reconnectAttempt)
        Task { @MainActor in
            statusStore.update(state: .reconnecting(attempt: reconnectAttempt))
            statusStore.record("Reconnect scheduled in \(String(format: "%.1f", delay))s")
        }
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connectWebSocket()
        }
    }

    private func handleNetwork(status: NetworkMonitor.Status) {
        switch status {
        case .satisfied:
            isNetworkAvailable = true
            if shouldReconnect {
                reconnectAttempt = 0
                connectWebSocket()
            }
        case .requiresConnection, .unsatisfied:
            isNetworkAvailable = false
            if !isSuspended, shouldReconnect {
                client.disconnect()
                Task { @MainActor in
                    statusStore.update(state: .disconnected(reason: "Network unavailable"))
                    statusStore.record("Network unavailable")
                }
            }
        }
    }

    private func handleLifecycle(event: AppLifecycleMonitor.Event) {
        switch event {
        case .background:
            isSuspended = true
            client.disconnect()
            Task { @MainActor in
                statusStore.update(state: .disconnected(reason: "App backgrounded"))
                statusStore.record("App backgrounded")
            }
        case .foreground:
            isSuspended = false
            if shouldReconnect {
                connectWebSocket()
            }
            Task { @MainActor in
                statusStore.record("App foregrounded")
            }
        }
    }
}
