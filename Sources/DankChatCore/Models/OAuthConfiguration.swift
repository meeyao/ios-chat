import Foundation

public struct OAuthConfiguration: Sendable, Equatable {
    public var clientId: String
    public var redirectURI: String
    public var scopes: [String]

    public init(clientId: String, redirectURI: String, scopes: [String]) {
        self.clientId = clientId
        self.redirectURI = redirectURI
        self.scopes = scopes
    }
}
