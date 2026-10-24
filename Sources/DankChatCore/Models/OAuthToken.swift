import Foundation

public struct OAuthToken: Codable, Equatable {
    public let accessToken: String
    public let refreshToken: String?
    public let scope: [String]
    public let tokenType: String
    public let expiresAt: Date

    public init(
        accessToken: String,
        refreshToken: String?,
        scope: [String],
        tokenType: String,
        expiresAt: Date
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.scope = scope
        self.tokenType = tokenType
        self.expiresAt = expiresAt
    }

    public func isExpired(reference: Date = Date()) -> Bool {
        expiresAt <= reference
    }

    public func shouldRefresh(reference: Date = Date(), leeway: TimeInterval = 60) -> Bool {
        expiresAt <= reference.addingTimeInterval(leeway)
    }
}
