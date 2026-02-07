import Foundation

public enum ChatEvent: Equatable {
    case message(ChatMessage)
    case system(SystemMessage)

    public var timestamp: Date {
        switch self {
        case .message(let message):
            return message.timestamp
        case .system(let message):
            return message.timestamp
        }
    }

    public var messageId: String? {
        switch self {
        case .message(let message):
            return message.id
        case .system:
            return nil
        }
    }

    public var channel: String? {
        switch self {
        case .message(let message):
            return message.channel
        case .system(let message):
            return message.channel
        }
    }
}

public struct SystemMessage: Equatable {
    public let text: String
    public let timestamp: Date
    public let kind: SystemMessageKind
    public let channel: String?

    public init(text: String, timestamp: Date, kind: SystemMessageKind, channel: String?) {
        self.text = text
        self.timestamp = timestamp
        self.kind = kind
        self.channel = channel
    }
}

public enum SystemMessageKind: String, Equatable {
    case notice
    case userNotice
    case roomState
    case moderation
}
