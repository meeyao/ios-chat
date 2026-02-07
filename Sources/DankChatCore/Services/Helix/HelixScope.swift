import Foundation

/// String constants for Twitch Helix OAuth scopes required by social and moderation features.
public enum HelixScope {
    // MARK: - Chat

    public static let chatRead = "chat:read"
    public static let chatEdit = "chat:edit"

    // MARK: - Moderation

    public static let moderatorManageBannedUsers = "moderator:manage:banned_users"
    public static let moderatorManageChatMessages = "moderator:manage:chat_messages"
    public static let moderatorManageChatSettings = "moderator:manage:chat_settings"
    public static let moderatorReadChatSettings = "moderator:read:chat_settings"
    public static let moderatorReadFollowers = "moderator:read:followers"

    // MARK: - User

    public static let userManageBlockedUsers = "user:manage:blocked_users"
    public static let userManageWhispers = "user:manage:whispers"

    // MARK: - Convenience

    /// Default scopes for DankChat social and moderation features.
    public static let defaultScopes: [String] = [
        chatRead,
        chatEdit,
        moderatorManageBannedUsers,
        moderatorManageChatMessages,
        moderatorManageChatSettings,
        moderatorReadChatSettings,
        moderatorReadFollowers,
        userManageBlockedUsers,
        userManageWhispers,
    ]
}
