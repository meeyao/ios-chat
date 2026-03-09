import Foundation

/// A lightweight HTTP client for the Twitch Helix API.
///
/// Injects `Client-Id` and `Authorization: Bearer` headers automatically.
/// Feature-specific services (users, moderation, etc.) wrap this client
/// with typed request/response helpers.
@available(macOS 12.0, iOS 15.0, *)
public final class HelixAPIClient: @unchecked Sendable {
    private let clientId: String
    private let tokenProvider: () async -> String?
    private let urlSession: URLSession
    private let baseURL: URL

    /// Creates a new Helix API client.
    ///
    /// - Parameters:
    ///   - clientId: The Twitch application client ID.
    ///   - tokenProvider: A closure that returns the current OAuth access token, or `nil` if unauthenticated.
    ///   - urlSession: The URL session used for network requests. Defaults to `.shared`.
    ///   - baseURL: The Helix base URL. Defaults to `https://api.twitch.tv/helix`.
    public init(
        clientId: String,
        tokenProvider: @escaping () async -> String?,
        urlSession: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.twitch.tv/helix")!
    ) {
        self.clientId = clientId
        self.tokenProvider = tokenProvider
        self.urlSession = urlSession
        self.baseURL = baseURL
    }

    /// Executes a Helix request and decodes the response into the given `Decodable` type.
    ///
    /// - Parameter helixRequest: The request descriptor (method, path, query, body).
    /// - Returns: The decoded response of type `T`.
    /// - Throws: `HelixError` on authentication, network, or decoding failures.
    public func execute<T: Decodable>(_ helixRequest: HelixRequest) async throws -> T {
        guard let token = await tokenProvider(), !token.isEmpty else {
            throw HelixError.missingAccessToken
        }

        let urlRequest = try buildURLRequest(helixRequest, token: token)
        let (data, response) = try await urlSession.data(for: urlRequest)
        try validate(response: response, data: data)

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HelixError.decodingError(error.localizedDescription)
        }
    }

    /// Executes a Helix request that returns no meaningful body (e.g. DELETE, 204 responses).
    ///
    /// - Parameter helixRequest: The request descriptor.
    /// - Throws: `HelixError` on authentication or network failures.
    public func executeNoContent(_ helixRequest: HelixRequest) async throws {
        guard let token = await tokenProvider(), !token.isEmpty else {
            throw HelixError.missingAccessToken
        }

        let urlRequest = try buildURLRequest(helixRequest, token: token)
        let (data, response) = try await urlSession.data(for: urlRequest)
        try validate(response: response, data: data)
    }

    // MARK: - Private

    private func buildURLRequest(_ helixRequest: HelixRequest, token: String) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw HelixError.invalidURL
        }

        // Append path (baseURL already ends at /helix)
        components.path += helixRequest.path

        if !helixRequest.queryItems.isEmpty {
            components.queryItems = helixRequest.queryItems
        }

        guard let url = components.url else {
            throw HelixError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = helixRequest.method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(clientId, forHTTPHeaderField: "Client-Id")

        if let body = helixRequest.body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw HelixError.httpError(statusCode: http.statusCode, payload: data)
        }
    }
}
