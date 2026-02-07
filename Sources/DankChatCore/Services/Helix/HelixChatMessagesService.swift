import Foundation

/// Wraps the Helix `DELETE /moderation/chat` endpoint for deleting individual messages
/// or clearing all chat in a channel.
///
/// Requires the `moderator:manage:chat_messages` OAuth scope.
/// The `moderatorId` must match the authenticated user and have moderator (or broadcaster)
/// privileges in the target channel.
public final class HelixChatMessagesService {
    private let client: HelixAPIClient

    /// Creates a new chat messages moderation service.
    ///
    /// - Parameter client: The Helix API client used for network requests.
    public init(client: HelixAPIClient) {
        self.client = client
    }

    // MARK: - Delete Single Message

    /// Deletes a single chat message by its ID.
    ///
    /// - Parameters:
    ///   - broadcasterId: The channel (broadcaster) ID where the message was sent.
    ///   - moderatorId: The moderator performing the action (must match the token owner).
    ///   - messageId: The ID of the message to delete.
    /// - Throws: `HelixError` on failure (e.g. 404 if message not found, 403 if not a moderator).
    public func deleteMessage(
        broadcasterId: String,
        moderatorId: String,
        messageId: String
    ) async throws {
        let request = HelixRequest(
            method: "DELETE",
            path: "/moderation/chat",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterId),
                URLQueryItem(name: "moderator_id", value: moderatorId),
                URLQueryItem(name: "message_id", value: messageId),
            ],
            requiredScopes: [HelixScope.moderatorManageChatMessages]
        )

        try await client.executeNoContent(request)
    }

    // MARK: - Clear Chat

    /// Clears all chat messages in a channel.
    ///
    /// When no `message_id` is provided, the Helix endpoint clears the entire chat.
    ///
    /// - Parameters:
    ///   - broadcasterId: The channel (broadcaster) ID to clear.
    ///   - moderatorId: The moderator performing the action (must match the token owner).
    /// - Throws: `HelixError` on failure.
    public func clearChat(
        broadcasterId: String,
        moderatorId: String
    ) async throws {
        let request = HelixRequest(
            method: "DELETE",
            path: "/moderation/chat",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterId),
                URLQueryItem(name: "moderator_id", value: moderatorId),
            ],
            requiredScopes: [HelixScope.moderatorManageChatMessages]
        )

        try await client.executeNoContent(request)
    }
}
