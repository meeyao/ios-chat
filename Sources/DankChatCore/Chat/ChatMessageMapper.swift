import Foundation

public struct ChatMessageMapper {
    nonisolated(unsafe) private static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    public init() {}

    public func map(_ message: IRCMessage) -> ChatEvent? {
        let receivedAt = Date()
        let serverTimestamp = Self.serverTimestamp(from: message)

        switch message.command {
        case "PRIVMSG":
            return mapPrivmsg(message, receivedAt: receivedAt, serverTimestamp: serverTimestamp)
        case "NOTICE":
            return mapSystem(message, kind: .notice, receivedAt: receivedAt, serverTimestamp: serverTimestamp)
        case "USERNOTICE":
            return mapSystem(message, kind: .userNotice, receivedAt: receivedAt, serverTimestamp: serverTimestamp)
        case "ROOMSTATE":
            return mapSystem(message, kind: .roomState, receivedAt: receivedAt, serverTimestamp: serverTimestamp)
        default:
            return nil
        }
    }

    private func mapPrivmsg(
        _ message: IRCMessage,
        receivedAt: Date,
        serverTimestamp: Date?
    ) -> ChatEvent? {
        guard let channelParam = message.params.first else { return nil }
        let channel = Self.normalizeChannel(channelParam)
        let rawText = message.params.last ?? ""
        let (text, isAction) = Self.parseAction(from: rawText)
        let displayName = Self.displayName(from: message)
        let login = Self.login(from: message, fallback: displayName)
        let twitchEmotes = TwitchEmoteTagParser.parse(Self.tagValue("emotes", in: message), in: text)
        let badgeTags = TwitchBadgeTagParser.parse(Self.tagValue("badges", in: message))
        let user = ChatUser(
            id: Self.tagValue("user-id", in: message),
            displayName: displayName,
            login: login,
            color: Self.tagValue("color", in: message)
        )
        let timestamp = serverTimestamp ?? receivedAt
        let latencyMs = serverTimestamp.map { Self.latencyMs(receivedAt: receivedAt, serverTimestamp: $0) }
        let replyMetadata = Self.parseReplyMetadata(from: message)
        let chatMessage = ChatMessage(
            id: Self.tagValue("id", in: message),
            user: user,
            text: text,
            timestamp: timestamp,
            receivedAt: receivedAt,
            latencyMs: latencyMs,
            isAction: isAction,
            channel: channel,
            twitchEmotes: twitchEmotes,
            badgeTags: badgeTags,
            replyMetadata: replyMetadata
        )
        return .message(chatMessage)
    }

    private func mapSystem(
        _ message: IRCMessage,
        kind: SystemMessageKind,
        receivedAt: Date,
        serverTimestamp: Date?
    ) -> ChatEvent? {
        let channel = message.params.first.map { Self.normalizeChannel($0) }
        let text = message.params.last ?? ""
        let timestamp = serverTimestamp ?? receivedAt
        return .system(SystemMessage(text: text, timestamp: timestamp, kind: kind, channel: channel))
    }

    private static func tagValue(_ key: String, in message: IRCMessage) -> String? {
        guard let value = message.tags[key] else { return nil }
        return value
    }

    private static func serverTimestamp(from message: IRCMessage) -> Date? {
        if let timeValue = tagValue("time", in: message) {
            if let parsed = isoFormatterWithFractional.date(from: timeValue) ?? isoFormatter.date(from: timeValue) {
                return parsed
            }
        }

        if let tmiValue = tagValue("tmi-sent-ts", in: message), let millis = Double(tmiValue) {
            return Date(timeIntervalSince1970: millis / 1000.0)
        }

        return nil
    }

    private static func displayName(from message: IRCMessage) -> String {
        if let value = tagValue("display-name", in: message), !value.isEmpty {
            return value
        }
        return login(from: message, fallback: "")
    }

    private static func login(from message: IRCMessage, fallback: String) -> String {
        if let prefix = message.prefix, let name = prefix.split(separator: "!").first {
            return String(name)
        }
        return fallback
    }

    private static func normalizeChannel(_ input: String) -> String {
        guard input.hasPrefix("#") else { return input }
        return String(input.dropFirst())
    }

    private static func parseAction(from text: String) -> (String, Bool) {
        guard text.hasPrefix("\u{0001}ACTION ") else {
            return (text, false)
        }
        guard text.hasSuffix("\u{0001}") else {
            return (text, false)
        }
        let start = text.index(text.startIndex, offsetBy: 8)
        let end = text.index(before: text.endIndex)
        return (String(text[start..<end]), true)
    }

    private static func latencyMs(receivedAt: Date, serverTimestamp: Date) -> Int {
        Int((receivedAt.timeIntervalSince(serverTimestamp) * 1000.0).rounded())
    }

    /// Parses reply metadata from IRC `reply-parent-*` tags.
    ///
    /// Returns `nil` when the `reply-parent-msg-id` tag is absent, meaning the
    /// message is not a reply.
    private static func parseReplyMetadata(from message: IRCMessage) -> ReplyMetadata? {
        guard let parentMsgId = tagValue("reply-parent-msg-id", in: message),
              !parentMsgId.isEmpty else {
            return nil
        }
        return ReplyMetadata(
            parentMessageId: parentMsgId,
            parentUserId: tagValue("reply-parent-user-id", in: message),
            parentUserLogin: tagValue("reply-parent-user-login", in: message),
            parentDisplayName: tagValue("reply-parent-display-name", in: message),
            parentMessageBody: tagValue("reply-parent-msg-body", in: message)
        )
    }
}
