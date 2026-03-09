import Foundation

/// A Helix user object returned by `GET /users`.
public struct HelixUser: Decodable, Equatable, Sendable {
    /// The Twitch user ID (numeric string).
    public let id: String
    /// The lowercase login name.
    public let login: String
    /// The display name (may contain casing and unicode).
    public let displayName: String

    public init(id: String, login: String, displayName: String) {
        self.id = id
        self.login = login
        self.displayName = displayName
    }
}

/// Wraps the Helix `GET /users` endpoint.
@available(macOS 12.0, iOS 15.0, *)
public final class HelixUsersService: Sendable {
    private let client: HelixAPIClient

    public init(client: HelixAPIClient) {
        self.client = client
    }

    /// Fetches the currently authenticated user (no query parameters needed).
    ///
    /// - Returns: The `HelixUser` for the token owner, or `nil` if the response contains no users.
    /// - Throws: `HelixError` on network or decoding failure.
    public func getCurrentUser() async throws -> HelixUser? {
        let request = HelixRequest(path: "/users")
        let response: HelixUsersResponse = try await client.execute(request)
        return response.data.first
    }

    /// Fetches users by their login names.
    ///
    /// - Parameter logins: Up to 100 login names.
    /// - Returns: An array of matching `HelixUser` objects.
    /// - Throws: `HelixError` on network or decoding failure.
    public func getUsers(logins: [String]) async throws -> [HelixUser] {
        let queryItems = logins.map { URLQueryItem(name: "login", value: $0) }
        let request = HelixRequest(path: "/users", queryItems: queryItems)
        let response: HelixUsersResponse = try await client.execute(request)
        return response.data
    }

    /// Fetches users by their IDs.
    ///
    /// - Parameter ids: Up to 100 user IDs.
    /// - Returns: An array of matching `HelixUser` objects.
    /// - Throws: `HelixError` on network or decoding failure.
    public func getUsers(ids: [String]) async throws -> [HelixUser] {
        let queryItems = ids.map { URLQueryItem(name: "id", value: $0) }
        let request = HelixRequest(path: "/users", queryItems: queryItems)
        let response: HelixUsersResponse = try await client.execute(request)
        return response.data
    }
}

// MARK: - Response types

private struct HelixUsersResponse: Decodable {
    let data: [HelixUser]
}
