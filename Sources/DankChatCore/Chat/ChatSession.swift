import Foundation

public final class ChatSession: @unchecked Sendable {
    private let supervisor: IRCConnectionSupervisor
    private let channelStore: ChannelStore
    private let mapper = ChatMessageMapper()
    private var buffer = ""

    public init(
        supervisor: IRCConnectionSupervisor,
        channelStore: ChannelStore,
        channel: String? = nil
    ) {
        self.supervisor = supervisor
        self.channelStore = channelStore
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
        supervisor.enqueueJoin(target)
    }

    public func part(channel: String) {
        let target = Self.normalizeChannel(channel)
        supervisor.sendRaw("PART #\(target)")
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

        // Update channel room state before mapping to a system message.
        if message.command == "ROOMSTATE" {
            if let channelParam = message.params.first {
                let channelId = Self.normalizeChannel(channelParam)
                var state = channelStore.state(for: channelId) ?? ChannelState()
                state.roomState = RoomStateParser.parse(tags: message.tags, merging: state.roomState)
                channelStore.updateState(state, for: channelId)
            }
        }

        if let event = mapper.map(message) {
            guard let channelId = event.channel else { return }
            channelStore.store(for: channelId).append(event: event)
        }
    }

    private static func normalizeChannel(_ input: String) -> String {
        guard input.hasPrefix("#") else { return input }
        return String(input.dropFirst())
    }
}
