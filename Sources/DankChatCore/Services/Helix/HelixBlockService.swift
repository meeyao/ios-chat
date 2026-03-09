import Foundation

/// Wraps the Helix block/unblock user endpoints.
///
/// - `PUT /users/blocks` -- blocks a user (requires `user:manage:blocked_users`).
/// - `DELETE /users/blocks` -- unblocks a user (requires `user:manage:blocked_users`).
/// - `GET /users/blocks` -- lists blocked users (requires `user:read:blocked_users` or `user:manage:blocked_users`).
@available(macOS 12.0, iOS 15.0, *)
public final class HelixBlockService: Sendable {
    private let client: HelixAPIClient

    public init(client: HelixAPIClient) {
        self.client = client
    }

    /// Blocks a user.
    ///
    /// - Parameter targetUserId: The Twitch user ID to block.
    /// - Throws: `HelixError` on failure (e.g. 401 if scope is missing).
    public func blockUser(targetUserId: String) async throws {
        let queryItems = [URLQueryItem(name: "target_user_id", value: targetUserId)]
        let request = HelixRequest(
            method: "PUT",
            path: "/users/blocks",
            queryItems: queryItems,
            requiredScopes: [HelixScope.userManageBlockedUsers]
        )
        try await client.executeNoContent(request)
    }

    /// Unblocks a user.
    ///
    /// - Parameter targetUserId: The Twitch user ID to unblock.
    /// - Throws: `HelixError` on failure (e.g. 401 if scope is missing).
    public func unblockUser(targetUserId: String) async throws {
        let queryItems = [URLQueryItem(name: "target_user_id", value: targetUserId)]
        let request = HelixRequest(
            method: "DELETE",
            path: "/users/blocks",
            queryItems: queryItems,
            requiredScopes: [HelixScope.userManageBlockedUsers]
        )
        try await client.executeNoContent(request)
    }

    /// Fetches the list of users blocked by the authenticated user.
    ///
    /// - Parameter broadcasterId: The authenticated user's ID.
    /// - Returns: An array of blocked user records.
    /// - Throws: `HelixError` on failure.
    public func getBlockedUsers(broadcasterId: String) async throws -> [HelixBlockedUser] {
        var allBlocked: [HelixBlockedUser] = []
        var cursor: String?

        repeat {
            var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
            queryItems.append(URLQueryItem(name: "first", value: "100"))
            if let cursor {
                queryItems.append(URLQueryItem(name: "after", value: cursor))
            }

            let request = HelixRequest(
                path: "/users/blocks",
                queryItems: queryItems,
                requiredScopes: [HelixScope.userManageBlockedUsers]
            )
            let response: HelixBlockListResponse = try await client.execute(request)
            allBlocked.append(contentsOf: response.data)
            cursor = response.pagination?.cursor
        } while cursor != nil

        return allBlocked
    }
}

// MARK: - Response types

/// A blocked user record returned by `GET /users/blocks`.
public struct HelixBlockedUser: Decodable, Equatable, Sendable {
    /// The blocked user's ID.
    public let userId: String
    /// The blocked user's login name.
    public let userLogin: String
    /// The blocked user's display name.
    public let displayName: String

    public init(userId: String, userLogin: String, displayName: String) {
        self.userId = userId
        self.userLogin = userLogin
        self.displayName = displayName
    }
}

private struct HelixBlockListResponse: Decodable {
    let data: [HelixBlockedUser]
    let pagination: HelixPagination?
}

private struct HelixPagination: Decodable {
    let cursor: String?
}
