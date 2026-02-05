import Foundation

public final class ChatSession {
    private let supervisor: IRCConnectionSupervisor
    private let store: ChatStore
    private let settings: ChatSettings
    private let mapper = ChatMessageMapper()
    private var buffer = ""

    public init(
        supervisor: IRCConnectionSupervisor,
        store: ChatStore,
        settings: ChatSettings,
        channel: String? = nil
    ) {
        self.supervisor = supervisor
        self.store = store
        self.settings = settings
        supervisor.onMessage = { [weak self] text in
            self?.handleIncoming(text)
        }

        if let channel {
            join(channel: channel)
        }
    }

    public func sendMessage(text: String, channel: String) {
        let target = Self.normalizeChannel(channel)
        supervisor.sendRaw("PRIVMSG #\(target) :\(text)")
    }

    public func join(channel: String) {
        let target = Self.normalizeChannel(channel)
        supervisor.sendRaw("JOIN #\(target)")
    }

    private func handleIncoming(_ text: String) {
        buffer.append(text)
        drainBuffer()
    }

    private func drainBuffer() {
        while let range = buffer.range(of: "\r\n") {
            let line = String(buffer[..<range.lowerBound])
            buffer.removeSubrange(..<range.upperBound)
            handleLine(line)
        }
    }

    private func handleLine(_ line: String) {
        guard let message = IRCMessageParser.parse(line: line) else { return }
        if message.command == "PING" {
            supervisor.sendRaw("PONG :tmi.twitch.tv")
            return
        }

        if let event = mapper.map(message) {
            store.append(event: event)
        }
    }

    private static func normalizeChannel(_ input: String) -> String {
        guard input.hasPrefix("#") else { return input }
        return String(input.dropFirst())
    }
}
