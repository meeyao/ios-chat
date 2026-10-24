import Foundation

public struct IRCConfiguration: Sendable {
    public let endpoint: URL
    public let nickname: String
    public let user: String
    public let oauthToken: String

    public init(
        endpoint: URL = URL(string: "wss://irc-ws.chat.twitch.tv:443")!,
        nickname: String,
        user: String,
        oauthToken: String
    ) {
        self.endpoint = endpoint
        self.nickname = nickname
        self.user = user
        self.oauthToken = oauthToken
    }
}
