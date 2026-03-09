import Foundation

/// Extended user profile returned by `GET /users` with additional fields
/// beyond the core `HelixUser` (which only carries id, login, displayName).
public struct HelixUserProfile: Decodable, Equatable, Sendable {
    /// The Twitch user ID (numeric string).
    public let id: String
    /// The lowercase login name.
    public let login: String
    /// The display name (may contain casing and unicode).
    public let displayName: String
    /// URL of the user's profile image.
    public let profileImageUrl: String?
    /// The user's channel description / bio.
    public let userDescription: String?
    /// Account creation date (ISO 8601 string).
    public let createdAt: String?
    /// Broadcaster type: "partner", "affiliate", or "" (normal).
    public let broadcasterType: String?

    private enum CodingKeys: String, CodingKey {
        case id, login, displayName, profileImageUrl
        case userDescription = "description"
        case createdAt, broadcasterType
    }

    public init(
        id: String,
        login: String,
        displayName: String,
        profileImageUrl: String? = nil,
        userDescription: String? = nil,
        createdAt: String? = nil,
        broadcasterType: String? = nil
    ) {
        self.id = id
        self.login = login
        self.displayName = displayName
        self.profileImageUrl = profileImageUrl
        self.userDescription = userDescription
        self.createdAt = createdAt
        self.broadcasterType = broadcasterType
    }
}

/// Wraps the Helix `GET /users` endpoint and returns full profile data.
///
/// Unlike `HelixUsersService` (which returns lightweight `HelixUser` objects),
/// this service returns `HelixUserProfile` with avatar, bio, and account age.
public final class HelixUserProfileService: Sendable {
    private let client: HelixAPIClient

    public init(client: HelixAPIClient) {
        self.client = client
    }

    /// Fetches a user profile by user ID.
    ///
    /// - Parameter userId: The Twitch user ID.
    /// - Returns: The full user profile, or `nil` if not found.
    /// - Throws: `HelixError` on network or decoding failure.
    public func getProfile(userId: String) async throws -> HelixUserProfile? {
        let queryItems = [URLQueryItem(name: "id", value: userId)]
        let request = HelixRequest(path: "/users", queryItems: queryItems)
        let response: HelixUserProfileListResponse = try await client.execute(request)
        return response.data.first
    }

    /// Fetches a user profile by login name.
    ///
    /// - Parameter login: The Twitch login name.
    /// - Returns: The full user profile, or `nil` if not found.
    /// - Throws: `HelixError` on network or decoding failure.
    public func getProfile(login: String) async throws -> HelixUserProfile? {
        let queryItems = [URLQueryItem(name: "login", value: login)]
        let request = HelixRequest(path: "/users", queryItems: queryItems)
        let response: HelixUserProfileListResponse = try await client.execute(request)
        return response.data.first
    }
}

// MARK: - Response types

private struct HelixUserProfileListResponse: Decodable {
    let data: [HelixUserProfile]
}
