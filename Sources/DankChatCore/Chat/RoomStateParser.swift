import Foundation

/// Parses IRC ROOMSTATE tags into a `RoomState` value.
///
/// Twitch sends ROOMSTATE messages when a channel's chat modes change. The tags included are:
/// - `slow`: Seconds between messages (0 = off)
/// - `followers-only`: Minimum follow duration in minutes (-1 = off, 0 = any follower)
/// - `subs-only`: 1 = on, 0 = off
/// - `emote-only`: 1 = on, 0 = off
/// - `r9k`: 1 = on, 0 = off (unique chat mode)
///
/// A ROOMSTATE may be a full state (on join) or a partial update (when a single mode changes).
/// This parser merges partial updates into an existing `RoomState`.
public enum RoomStateParser {

    /// Parses ROOMSTATE tags into a new `RoomState`, optionally merging with an existing state.
    ///
    /// - Parameters:
    ///   - tags: The IRC message tags dictionary from a ROOMSTATE command.
    ///   - existing: The current room state to merge partial updates into. Pass `nil` for first parse.
    /// - Returns: The updated `RoomState` reflecting the tag values.
    public static func parse(tags: [String: String?], merging existing: RoomState? = nil) -> RoomState {
        var state = existing ?? RoomState()

        if let slowRaw = tags["slow"], let slowString = slowRaw, let seconds = Int(slowString) {
            // 0 means slow mode is off
            state.slowModeSeconds = seconds > 0 ? seconds : nil
        }

        if let followersRaw = tags["followers-only"], let followersString = followersRaw, let minutes = Int(followersString) {
            // -1 means followers-only is off
            state.followersOnlyMinutes = minutes >= 0 ? minutes : nil
        }

        if let subsRaw = tags["subs-only"], let subsString = subsRaw {
            state.isSubsOnly = subsString == "1"
        }

        if let emoteRaw = tags["emote-only"], let emoteString = emoteRaw {
            state.isEmoteOnly = emoteString == "1"
        }

        if let r9kRaw = tags["r9k"], let r9kString = r9kRaw {
            state.isUniqueChat = r9kString == "1"
        }

        return state
    }
}
