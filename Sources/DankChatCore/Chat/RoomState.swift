import Foundation

/// Models the current room state for a Twitch channel, derived from IRC ROOMSTATE tags.
///
/// Each property corresponds to a chat mode that moderators can toggle. Properties are optional
/// because a ROOMSTATE update may only include changed fields (partial updates).
public struct RoomState: Equatable, Sendable {
    /// Slow mode cooldown in seconds, or `nil` if slow mode is off (tag value 0).
    public var slowModeSeconds: Int?

    /// Followers-only minimum duration in minutes, or `nil` if followers-only is off (tag value -1).
    ///
    /// A value of 0 means any follower can chat (no minimum follow time).
    public var followersOnlyMinutes: Int?

    /// Whether the channel is in subscribers-only mode.
    public var isSubsOnly: Bool

    /// Whether the channel is in emote-only mode.
    public var isEmoteOnly: Bool

    /// Whether the channel is in unique-chat (R9K) mode.
    public var isUniqueChat: Bool

    public init(
        slowModeSeconds: Int? = nil,
        followersOnlyMinutes: Int? = nil,
        isSubsOnly: Bool = false,
        isEmoteOnly: Bool = false,
        isUniqueChat: Bool = false
    ) {
        self.slowModeSeconds = slowModeSeconds
        self.followersOnlyMinutes = followersOnlyMinutes
        self.isSubsOnly = isSubsOnly
        self.isEmoteOnly = isEmoteOnly
        self.isUniqueChat = isUniqueChat
    }

    /// A human-readable summary of active room modes for display in system messages.
    ///
    /// Returns `nil` when no modes are active.
    public var summary: String? {
        var parts: [String] = []

        if let seconds = slowModeSeconds, seconds > 0 {
            parts.append("Slow mode: \(seconds)s")
        }
        if let minutes = followersOnlyMinutes, minutes >= 0 {
            if minutes == 0 {
                parts.append("Followers-only")
            } else {
                parts.append("Followers-only: \(minutes)m")
            }
        }
        if isSubsOnly {
            parts.append("Subscribers-only")
        }
        if isEmoteOnly {
            parts.append("Emote-only")
        }
        if isUniqueChat {
            parts.append("Unique chat")
        }

        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
