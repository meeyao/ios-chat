import Foundation

/// Errors surfaced by `HelixAPIClient` when a Helix API call fails.
public enum HelixError: Error, Equatable {
    /// The token provider returned `nil` or an empty string.
    case missingAccessToken

    /// Could not construct a valid URL for the request.
    case invalidURL

    /// The server returned a non-2xx HTTP status code.
    case httpError(statusCode: Int, payload: Data)

    /// The response body could not be decoded into the expected type.
    case decodingError(String)
}
