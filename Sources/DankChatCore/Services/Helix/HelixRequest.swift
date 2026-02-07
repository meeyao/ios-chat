import Foundation

/// Describes a single Helix API request.
public struct HelixRequest: Sendable {
    /// HTTP method (GET, POST, PATCH, DELETE, PUT).
    public let method: String

    /// Path relative to the Helix base URL (e.g. "/users", "/moderation/bans").
    public let path: String

    /// Query parameters appended to the URL.
    public let queryItems: [URLQueryItem]

    /// Optional JSON-encoded body for POST/PATCH/PUT requests.
    public let body: Data?

    /// OAuth scopes required for this request (informational, not enforced by the client).
    public let requiredScopes: [String]

    public init(
        method: String = "GET",
        path: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        requiredScopes: [String] = []
    ) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.body = body
        self.requiredScopes = requiredScopes
    }
}
