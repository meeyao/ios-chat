import Foundation

public enum IRCConnectionState: Equatable, Sendable {
    case disconnected(reason: String?)
    case connecting
    case reconnecting(attempt: Int)
    case connected
}

public struct IRCConfiguration: Sendable {
    public static let defaultTwitch = URL(string: "wss://irc-ws.chat.twitch.tv:443")!

    public let endpoint: URL
    public let oauthToken: String
    public let nickname: String
    public let user: String
    
    public init(endpoint: URL, oauthToken: String, nickname: String, user: String) {
        self.endpoint = endpoint
        self.oauthToken = oauthToken
        self.nickname = nickname
        self.user = user
    }
}
