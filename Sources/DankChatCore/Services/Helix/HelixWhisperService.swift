import Foundation

/// Wraps the Helix `POST /whispers` endpoint for sending whisper messages.
///
/// Whisper delivery is **not guaranteed** -- the API may return 204 (success)
/// even when the message is silently dropped due to recipient settings,
/// rate limits, or phone verification requirements.
public final class HelixWhisperService {
    private let client: HelixAPIClient

    /// Creates a new whisper service.
    ///
    /// - Parameter client: The Helix API client used for network requests.
    public init(client: HelixAPIClient) {
        self.client = client
    }

    /// Sends a whisper from one user to another.
    ///
    /// - Parameters:
    ///   - fromUserId: The sender's Twitch user ID (must match the authenticated user).
    ///   - toUserId: The recipient's Twitch user ID.
    ///   - message: The whisper text to send.
    /// - Throws: `HelixError` on failure (e.g., 401 unauthorized, 400 invalid request).
    /// - Note: A successful call (no error thrown) does **not** guarantee the whisper
    ///   was delivered. The recipient may have whispers disabled or may not have a
    ///   verified phone number.
    public func sendWhisper(fromUserId: String, toUserId: String, message: String) async throws {
        let body = SendWhisperBody(message: message)
        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(body)

        let request = HelixRequest(
            method: "POST",
            path: "/whispers",
            queryItems: [
                URLQueryItem(name: "from_user_id", value: fromUserId),
                URLQueryItem(name: "to_user_id", value: toUserId),
            ],
            body: bodyData,
            requiredScopes: [HelixScope.userManageWhispers]
        )

        try await client.executeNoContent(request)
    }
}

// MARK: - Request Body

private struct SendWhisperBody: Encodable {
    let message: String
}
