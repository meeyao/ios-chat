import Foundation

public protocol OAuthTokenStore: Sendable {
    func readToken() throws -> OAuthToken?
    func writeToken(_ token: OAuthToken) throws
    func clearToken() throws
}
