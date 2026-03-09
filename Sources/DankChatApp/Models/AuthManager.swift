import Foundation
import DankChatCore
import Combine

public enum AuthState: Equatable, Sendable {
    case signedOut
    case signingIn
    case signedIn(OAuthToken)
    case error(String)
}

@MainActor
public final class AuthManager: ObservableObject {
    @Published public private(set) var state: AuthState = .signedOut
    private let configuration: OAuthConfiguration
    private let tokenStore: KeychainTokenStore
    private let oauthClient: OAuthClient
    private let authorizer: SystemOAuthAuthorizer

    public init(
        configuration: OAuthConfiguration,
        tokenStore: KeychainTokenStore,
        oauthClient: OAuthClient,
        authorizer: SystemOAuthAuthorizer
    ) {
        self.configuration = configuration
        self.tokenStore = tokenStore
        self.oauthClient = oauthClient
        self.authorizer = authorizer
    }

    public func restoreSession() {
        if let token = tokenStore.load() {
            state = .signedIn(token)
        } else {
            state = .signedOut
        }
    }

    public func beginLogin() async {
        state = .signingIn
        do {
            let callbackURL = try await authorizer.authorize(configuration: configuration)
            guard let code = extractCode(from: callbackURL) else {
                state = .error("Invalid callback URL")
                return
            }
            let token = try await oauthClient.exchangeCodeForToken(code)
            tokenStore.save(token)
            state = .signedIn(token)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    public func signOut() {
        tokenStore.clear()
        state = .signedOut
    }

    public func refreshIfNeeded() async {
        guard case let .signedIn(token) = state else { return }
        // Simplistic refresh check.
        guard let refreshToken = token.refreshToken, token.expiresAt < Date() else { return }
        do {
            let newToken = try await oauthClient.refreshToken(refreshToken)
            tokenStore.save(newToken)
            state = .signedIn(newToken)
        } catch {
            signOut()
        }
    }

    private func extractCode(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value
    }
}

public struct OAuthToken: Codable, Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date
    public let scope: [String]
}

public final class KeychainTokenStore: Sendable {
    private let service: String
    private let account: String

    public init(service: String, account: String) {
        self.service = service
        self.account = account
    }

    public func load() -> OAuthToken? { nil } // Stub
    public func save(_ token: OAuthToken) {} // Stub
    public func clear() {} // Stub
}

public final class OAuthClient: Sendable {
    private let configuration: OAuthConfiguration
    public init(configuration: OAuthConfiguration) { self.configuration = configuration }
    public func exchangeCodeForToken(_ code: String) async throws -> OAuthToken {
        OAuthToken(accessToken: "stub_access", refreshToken: "stub_refresh", expiresAt: Date().addingTimeInterval(3600), scope: [])
    }
    public func refreshToken(_ refreshToken: String) async throws -> OAuthToken {
        OAuthToken(accessToken: "stub_access_new", refreshToken: "stub_refresh_new", expiresAt: Date().addingTimeInterval(3600), scope: [])
    }
}

@MainActor
public final class SystemOAuthAuthorizer {
    public init() {}
    public func authorize(configuration: OAuthConfiguration) async throws -> URL {
        URL(string: "dankchat://callback?code=stub")!
    }
}
