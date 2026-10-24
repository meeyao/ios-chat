import Foundation

public final class IRCWebSocketClient: NSObject, URLSessionWebSocketDelegate {
    public enum Event: Sendable {
        case connected
        case disconnected(Error?)
        case message(String)
    }

    public var onEvent: (@Sendable (Event) -> Void)?

    private let configuration: URLSessionConfiguration
    private lazy var urlSession: URLSession = URLSession(
        configuration: configuration,
        delegate: self,
        delegateQueue: nil
    )
    private var task: URLSessionWebSocketTask?

    public init(configuration: URLSessionConfiguration = .default) {
        self.configuration = configuration
        super.init()
    }

    public func connect(to url: URL) {
        disconnect()
        let task = urlSession.webSocketTask(with: url)
        self.task = task
        task.resume()
        receiveLoop()
    }

    public func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    public func send(_ string: String) async {
        do {
            try await task?.send(.string(string))
        } catch {
            onEvent?(.disconnected(error))
        }
    }

    private func receiveLoop() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.onEvent?(.disconnected(error))
            case .success(let message):
                switch message {
                case .string(let text):
                    self.onEvent?(.message(text))
                case .data:
                    break
                @unknown default:
                    break
                }
                self.receiveLoop()
            }
        }
    }

    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        onEvent?(.connected)
    }

    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        onEvent?(.disconnected(nil))
    }
}
