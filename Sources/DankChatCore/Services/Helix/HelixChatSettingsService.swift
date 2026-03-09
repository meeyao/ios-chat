import Foundation

/// Wraps the Helix `GET /chat/settings` and `PATCH /chat/settings` endpoints.
///
/// Use this service to read and update chat room modes (slow, followers-only, subs-only,
/// emote-only, unique chat). Reading settings requires the `moderator:read:chat_settings`
/// scope; updating requires `moderator:manage:chat_settings`.
@available(macOS 12.0, iOS 15.0, *)
public final class HelixChatSettingsService: Sendable {
    private let client: HelixAPIClient

    /// Creates a new chat settings service.
    ///
    /// - Parameter client: The Helix API client used for network requests.
    public init(client: HelixAPIClient) {
        self.client = client
    }

    // MARK: - Get Chat Settings

    /// Fetches the current chat settings for a channel.
    ///
    /// - Parameters:
    ///   - broadcasterId: The channel (broadcaster) ID to query.
    ///   - moderatorId: The moderator performing the query (must match the token owner).
    /// - Returns: The current chat settings for the channel.
    /// - Throws: `HelixError` on failure.
    public func getChatSettings(
        broadcasterId: String,
        moderatorId: String
    ) async throws -> HelixChatSettings {
        let request = HelixRequest(
            method: "GET",
            path: "/chat/settings",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterId),
                URLQueryItem(name: "moderator_id", value: moderatorId),
            ],
            requiredScopes: [HelixScope.moderatorReadChatSettings]
        )

        let response: HelixChatSettingsResponse = try await client.execute(request)
        guard let settings = response.data.first else {
            throw HelixError.decodingError("Empty chat settings response")
        }
        return settings
    }

    // MARK: - Update Chat Settings

    /// Updates one or more chat settings for a channel.
    ///
    /// Only include the fields you want to change. Omitted fields remain unchanged.
    ///
    /// - Parameters:
    ///   - broadcasterId: The channel (broadcaster) ID to update.
    ///   - moderatorId: The moderator performing the update (must match the token owner).
    ///   - patch: The settings patch to apply.
    /// - Returns: The updated chat settings.
    /// - Throws: `HelixError` on failure.
    @discardableResult
    public func updateChatSettings(
        broadcasterId: String,
        moderatorId: String,
        patch: HelixChatSettingsPatch
    ) async throws -> HelixChatSettings {
        let bodyData = try JSONEncoder().encode(patch)

        let request = HelixRequest(
            method: "PATCH",
            path: "/chat/settings",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterId),
                URLQueryItem(name: "moderator_id", value: moderatorId),
            ],
            body: bodyData,
            requiredScopes: [HelixScope.moderatorManageChatSettings]
        )

        let response: HelixChatSettingsResponse = try await client.execute(request)
        guard let settings = response.data.first else {
            throw HelixError.decodingError("Empty chat settings update response")
        }
        return settings
    }
}

// MARK: - Response Types

/// The chat settings for a channel as returned by the Helix API.
public struct HelixChatSettings: Decodable, Equatable, Sendable {
    /// Whether slow mode is enabled.
    public let slowMode: Bool
    /// The delay in seconds between messages when slow mode is on.
    public let slowModeWaitTime: Int?
    /// Whether followers-only mode is enabled.
    public let followerMode: Bool
    /// The minimum follow duration in minutes (0 = any follower).
    public let followerModeDuration: Int?
    /// Whether subscriber-only mode is enabled.
    public let subscriberMode: Bool
    /// Whether emote-only mode is enabled.
    public let emoteMode: Bool
    /// Whether unique chat (R9K) mode is enabled.
    public let uniqueChatMode: Bool

    public init(
        slowMode: Bool = false,
        slowModeWaitTime: Int? = nil,
        followerMode: Bool = false,
        followerModeDuration: Int? = nil,
        subscriberMode: Bool = false,
        emoteMode: Bool = false,
        uniqueChatMode: Bool = false
    ) {
        self.slowMode = slowMode
        self.slowModeWaitTime = slowModeWaitTime
        self.followerMode = followerMode
        self.followerModeDuration = followerModeDuration
        self.subscriberMode = subscriberMode
        self.emoteMode = emoteMode
        self.uniqueChatMode = uniqueChatMode
    }

    /// Converts Helix chat settings to the internal `RoomState` model.
    public func toRoomState() -> RoomState {
        RoomState(
            slowModeSeconds: slowMode ? (slowModeWaitTime ?? 0) : nil,
            followersOnlyMinutes: followerMode ? (followerModeDuration ?? 0) : nil,
            isSubsOnly: subscriberMode,
            isEmoteOnly: emoteMode,
            isUniqueChat: uniqueChatMode
        )
    }
}

/// A partial update payload for `PATCH /chat/settings`.
///
/// Only set the fields you want to change; `nil` fields are omitted from the JSON body.
/// Uses a custom `encode(to:)` to skip nil values rather than encoding them as `null`.
public struct HelixChatSettingsPatch: Encodable, Equatable, Sendable {
    public var slowMode: Bool?
    public var slowModeWaitTime: Int?
    public var followerMode: Bool?
    public var followerModeDuration: Int?
    public var subscriberMode: Bool?
    public var emoteMode: Bool?
    public var uniqueChatMode: Bool?

    public init(
        slowMode: Bool? = nil,
        slowModeWaitTime: Int? = nil,
        followerMode: Bool? = nil,
        followerModeDuration: Int? = nil,
        subscriberMode: Bool? = nil,
        emoteMode: Bool? = nil,
        uniqueChatMode: Bool? = nil
    ) {
        self.slowMode = slowMode
        self.slowModeWaitTime = slowModeWaitTime
        self.followerMode = followerMode
        self.followerModeDuration = followerModeDuration
        self.subscriberMode = subscriberMode
        self.emoteMode = emoteMode
        self.uniqueChatMode = uniqueChatMode
    }

    // Custom encoding to omit nil values (Helix expects missing keys, not null).
    private enum CodingKeys: String, CodingKey {
        case slowMode = "slow_mode"
        case slowModeWaitTime = "slow_mode_wait_time"
        case followerMode = "follower_mode"
        case followerModeDuration = "follower_mode_duration"
        case subscriberMode = "subscriber_mode"
        case emoteMode = "emote_mode"
        case uniqueChatMode = "unique_chat_mode"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try slowMode.map { try container.encode($0, forKey: .slowMode) }
        try slowModeWaitTime.map { try container.encode($0, forKey: .slowModeWaitTime) }
        try followerMode.map { try container.encode($0, forKey: .followerMode) }
        try followerModeDuration.map { try container.encode($0, forKey: .followerModeDuration) }
        try subscriberMode.map { try container.encode($0, forKey: .subscriberMode) }
        try emoteMode.map { try container.encode($0, forKey: .emoteMode) }
        try uniqueChatMode.map { try container.encode($0, forKey: .uniqueChatMode) }
    }
}

private struct HelixChatSettingsResponse: Decodable {
    let data: [HelixChatSettings]
}
