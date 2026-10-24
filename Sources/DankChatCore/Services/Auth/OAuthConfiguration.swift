import Foundation

public struct OAuthConfiguration: Sendable {
    public let clientId: String
    public let redirectURI: String
    public let scopes: [String]
    public let authorizationEndpoint: URL
    public let tokenEndpoint: URL

    public init(
        clientId: String,
        redirectURI: String,
        scopes: [String],
        authorizationEndpoint: URL = URL(string: "https://id.twitch.tv/oauth2/authorize")!,
        tokenEndpoint: URL = URL(string: "https://id.twitch.tv/oauth2/token")!
    ) {
        self.clientId = clientId
        self.redirectURI = redirectURI
        self.scopes = scopes
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
    }
}
