import Foundation

/// A follower record from the Helix `GET /channels/followers` endpoint.
public struct HelixFollowRecord: Decodable, Equatable, Sendable {
    /// The user ID of the follower.
    public let userId: String
    /// The login name of the follower.
    public let userLogin: String
    /// The display name of the follower.
    public let userName: String
    /// ISO 8601 timestamp of when the user followed the channel.
    public let followedAt: String

    public init(userId: String, userLogin: String, userName: String, followedAt: String) {
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.followedAt = followedAt
    }
}

/// Wraps the Helix `GET /channels/followers` endpoint.
///
/// Requires the `moderator:read:followers` scope when querying specific
/// follower relationships. Returns follower information including follow date.
public final class HelixFollowageService: Sendable {
    private let client: HelixAPIClient

    public init(client: HelixAPIClient) {
        self.client = client
    }

    /// Checks whether a specific user follows a broadcaster.
    ///
    /// - Parameters:
    ///   - userId: The potential follower's user ID.
    ///   - broadcasterId: The broadcaster's user ID.
    /// - Returns: The follow record if the user follows the broadcaster, or `nil` if not following.
    /// - Throws: `HelixError` on network failure or if the required scope is missing (401/403).
    public func getFollowage(userId: String, broadcasterId: String) async throws -> HelixFollowRecord? {
        let queryItems = [
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "broadcaster_id", value: broadcasterId),
        ]
        let request = HelixRequest(
            path: "/channels/followers",
            queryItems: queryItems,
            requiredScopes: [HelixScope.moderatorReadFollowers]
        )
        let response: HelixFollowageResponse = try await client.execute(request)
        return response.data.first
    }
}

// MARK: - Response types

private struct HelixFollowageResponse: Decodable {
    let data: [HelixFollowRecord]
}
