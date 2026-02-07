import Foundation

/// Wraps the Helix ban/timeout/unban endpoints (`POST /moderation/bans`, `DELETE /moderation/bans`).
///
/// All methods require the `moderator:manage:banned_users` OAuth scope.
/// The `moderatorId` must match the authenticated user and have moderator (or broadcaster)
/// privileges in the target channel.
public final class HelixModerationService {
    private let client: HelixAPIClient

    /// Creates a new moderation service.
    ///
    /// - Parameter client: The Helix API client used for network requests.
    public init(client: HelixAPIClient) {
        self.client = client
    }

    // MARK: - Ban

    /// Permanently bans a user from a channel.
    ///
    /// - Parameters:
    ///   - broadcasterId: The channel (broadcaster) ID where the ban applies.
    ///   - moderatorId: The moderator performing the action (must match the token owner).
    ///   - userId: The user ID to ban.
    ///   - reason: Optional ban reason shown to the banned user.
    /// - Returns: The ban result from the Helix API.
    /// - Throws: `HelixError` on failure (e.g. 401 if scope is missing, 403 if not a moderator).
    @discardableResult
    public func banUser(
        broadcasterId: String,
        moderatorId: String,
        userId: String,
        reason: String? = nil
    ) async throws -> HelixBanResult {
        var bodyDict: [String: Any] = ["user_id": userId]
        if let reason, !reason.isEmpty {
            bodyDict["reason"] = reason
        }
        let wrapper: [String: Any] = ["data": bodyDict]
        let bodyData = try JSONSerialization.data(withJSONObject: wrapper)

        let request = HelixRequest(
            method: "POST",
            path: "/moderation/bans",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterId),
                URLQueryItem(name: "moderator_id", value: moderatorId),
            ],
            body: bodyData,
            requiredScopes: [HelixScope.moderatorManageBannedUsers]
        )

        let response: HelixBanResponse = try await client.execute(request)
        guard let result = response.data.first else {
            throw HelixError.decodingError("Empty ban response")
        }
        return result
    }

    // MARK: - Timeout

    /// Times out a user in a channel for a specified duration.
    ///
    /// - Parameters:
    ///   - broadcasterId: The channel (broadcaster) ID where the timeout applies.
    ///   - moderatorId: The moderator performing the action (must match the token owner).
    ///   - userId: The user ID to timeout.
    ///   - durationSeconds: The timeout duration in seconds (1 to 1_209_600, i.e. up to 2 weeks).
    ///   - reason: Optional timeout reason shown to the user.
    /// - Returns: The ban result from the Helix API.
    /// - Throws: `HelixError` on failure.
    @discardableResult
    public func timeoutUser(
        broadcasterId: String,
        moderatorId: String,
        userId: String,
        durationSeconds: Int,
        reason: String? = nil
    ) async throws -> HelixBanResult {
        var bodyDict: [String: Any] = [
            "user_id": userId,
            "duration": durationSeconds,
        ]
        if let reason, !reason.isEmpty {
            bodyDict["reason"] = reason
        }
        let wrapper: [String: Any] = ["data": bodyDict]
        let bodyData = try JSONSerialization.data(withJSONObject: wrapper)

        let request = HelixRequest(
            method: "POST",
            path: "/moderation/bans",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterId),
                URLQueryItem(name: "moderator_id", value: moderatorId),
            ],
            body: bodyData,
            requiredScopes: [HelixScope.moderatorManageBannedUsers]
        )

        let response: HelixBanResponse = try await client.execute(request)
        guard let result = response.data.first else {
            throw HelixError.decodingError("Empty timeout response")
        }
        return result
    }

    // MARK: - Unban

    /// Removes a ban or timeout for a user in a channel.
    ///
    /// - Parameters:
    ///   - broadcasterId: The channel (broadcaster) ID.
    ///   - moderatorId: The moderator performing the action (must match the token owner).
    ///   - userId: The user ID to unban.
    /// - Throws: `HelixError` on failure.
    public func unbanUser(
        broadcasterId: String,
        moderatorId: String,
        userId: String
    ) async throws {
        let request = HelixRequest(
            method: "DELETE",
            path: "/moderation/bans",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterId),
                URLQueryItem(name: "moderator_id", value: moderatorId),
                URLQueryItem(name: "user_id", value: userId),
            ],
            requiredScopes: [HelixScope.moderatorManageBannedUsers]
        )

        try await client.executeNoContent(request)
    }
}

// MARK: - Timeout Duration Presets

/// Common timeout durations used in moderation UIs.
public enum TimeoutDuration: Int, CaseIterable, Identifiable {
    case oneSecond = 1
    case thirtySeconds = 30
    case oneMinute = 60
    case tenMinutes = 600
    case thirtyMinutes = 1800
    case oneHour = 3600
    case oneDay = 86400
    case oneWeek = 604800
    case twoWeeks = 1209600

    public var id: Int { rawValue }

    /// A human-readable label for this duration.
    public var label: String {
        switch self {
        case .oneSecond: return "1 second"
        case .thirtySeconds: return "30 seconds"
        case .oneMinute: return "1 minute"
        case .tenMinutes: return "10 minutes"
        case .thirtyMinutes: return "30 minutes"
        case .oneHour: return "1 hour"
        case .oneDay: return "1 day"
        case .oneWeek: return "1 week"
        case .twoWeeks: return "2 weeks"
        }
    }
}

// MARK: - Response Types

/// A single ban/timeout result returned by `POST /moderation/bans`.
public struct HelixBanResult: Decodable, Equatable, Sendable {
    /// The broadcaster's user ID.
    public let broadcasterId: String
    /// The moderator's user ID.
    public let moderatorId: String
    /// The banned/timed-out user's ID.
    public let userId: String
    /// When the ban was created (ISO 8601).
    public let createdAt: String
    /// When the timeout ends (ISO 8601), or `nil` for permanent bans.
    public let endTime: String?

    public init(
        broadcasterId: String,
        moderatorId: String,
        userId: String,
        createdAt: String,
        endTime: String?
    ) {
        self.broadcasterId = broadcasterId
        self.moderatorId = moderatorId
        self.userId = userId
        self.createdAt = createdAt
        self.endTime = endTime
    }
}

private struct HelixBanResponse: Decodable {
    let data: [HelixBanResult]
}
