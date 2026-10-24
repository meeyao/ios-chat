import Foundation

public final class OAuthClient: @unchecked Sendable {
    private let configuration: OAuthConfiguration
    private let urlSession: URLSession

    public init(configuration: OAuthConfiguration, urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
    }

    public func authorizationURL(state: String, pkce: OAuthPKCE) -> URL {
        var components = URLComponents(url: configuration.authorizationEndpoint, resolvingAgainstBaseURL: false)
        let scope = configuration.scopes.joined(separator: " ")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: pkce.codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        return components?.url ?? configuration.authorizationEndpoint
    }

    public func exchange(code: String, pkce: OAuthPKCE) async throws -> OAuthToken {
        var request = URLRequest(url: configuration.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyItems = [
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "code_verifier", value: pkce.codeVerifier)
        ]
        request.httpBody = Self.formEncode(bodyItems).data(using: .utf8)

        let (data, response) = try await urlSession.data(for: request)
        try Self.validate(response: response, data: data)
        return try Self.decodeToken(from: data)
    }

    /// Starts Twitch's device-code grant. The user enters `userCode` at
    /// `verificationURI`, and the client polls for the token.
    public func requestDeviceCode() async throws -> DeviceCodeChallenge {
        var request = URLRequest(url: URL(string: "https://id.twitch.tv/oauth2/device")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncode([
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "scopes", value: configuration.scopes.joined(separator: " "))
        ]).data(using: .utf8)

        let (data, response) = try await urlSession.data(for: request)
        try Self.validate(response: response, data: data)

        let decoded = try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
        return DeviceCodeChallenge(
            deviceCode: decoded.deviceCode,
            userCode: decoded.userCode,
            verificationURI: decoded.verificationUri,
            expiresIn: decoded.expiresIn,
            interval: decoded.interval
        )
    }

    /// Polls the token endpoint for a device-code login.
    public func pollDeviceToken(deviceCode: String) async throws -> OAuthToken {
        var request = URLRequest(url: configuration.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncode([
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "scopes", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "device_code", value: deviceCode),
            URLQueryItem(name: "grant_type", value: "urn:ietf:params:oauth:grant-type:device_code")
        ]).data(using: .utf8)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OAuthError.invalidCallback
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(OAuthErrorResponse.self, from: data))?.message ?? ""
            switch message {
            case "authorization_pending":
                throw OAuthError.authorizationPending
            case "slow_down":
                throw OAuthError.slowDown
            case "expired_token":
                throw OAuthError.deviceCodeExpired
            case "access_denied":
                throw OAuthError.accessDenied
            default:
                throw OAuthError.httpError(statusCode: http.statusCode, payload: data)
            }
        }
        return try Self.decodeToken(from: data)
    }

    public func refresh(refreshToken: String) async throws -> OAuthToken {
        var request = URLRequest(url: configuration.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyItems = [
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken)
        ]
        request.httpBody = Self.formEncode(bodyItems).data(using: .utf8)

        let (data, response) = try await urlSession.data(for: request)
        try Self.validate(response: response, data: data)
        return try Self.decodeToken(from: data)
    }

    private static func decodeToken(from data: Data) throws -> OAuthToken {
        let decoder = JSONDecoder()
        let response = try decoder.decode(TokenResponse.self, from: data)
        let expiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        return OAuthToken(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            scope: response.scope,
            tokenType: response.tokenType,
            expiresAt: expiresAt
        )
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw OAuthError.httpError(statusCode: http.statusCode, payload: data)
        }
    }

    private static func formEncode(_ items: [URLQueryItem]) -> String {
        var components = URLComponents()
        components.queryItems = items
        return components.percentEncodedQuery ?? ""
    }
}

public enum OAuthError: Error, LocalizedError {
    case invalidCallback
    case invalidState
    case httpError(statusCode: Int, payload: Data)
    case missingRefreshToken
    case authorizationPending
    case slowDown
    case deviceCodeExpired
    case accessDenied

    public var errorDescription: String? {
        switch self {
        case .invalidCallback:
            return "Twitch returned an invalid OAuth callback."
        case .invalidState:
            return "OAuth state did not match."
        case .httpError(let statusCode, let payload):
            let body = String(data: payload, encoding: .utf8) ?? ""
            return "Twitch returned HTTP \(statusCode). \(body.prefix(200))"
        case .missingRefreshToken:
            return "No refresh token is available."
        case .authorizationPending:
            return "Waiting for authorization."
        case .slowDown:
            return "Twitch asked the client to poll more slowly."
        case .deviceCodeExpired:
            return "The login code expired."
        case .accessDenied:
            return "Twitch authorization was denied."
        }
    }
}

/// A Twitch device-code login challenge.
public struct DeviceCodeChallenge: Equatable, Sendable {
    public let deviceCode: String
    public let userCode: String
    public let verificationURI: String
    public let expiresIn: Int
    public let interval: Int

    public init(deviceCode: String, userCode: String, verificationURI: String, expiresIn: Int, interval: Int) {
        self.deviceCode = deviceCode
        self.userCode = userCode
        self.verificationURI = verificationURI
        self.expiresIn = expiresIn
        self.interval = interval
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let scope: [String]
    let tokenType: String

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case scope
        case tokenType = "token_type"
    }
}

private struct DeviceCodeResponse: Decodable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int

    private enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

private struct OAuthErrorResponse: Decodable {
    let status: Int
    let message: String
}
