import Combine
import Foundation
import os

@MainActor
public final class AuthManager: ObservableObject {
    public enum State: Equatable {
        case signedOut
        case signingIn
        case signedIn(OAuthToken)
        case error(String)
    }

    public struct DeviceLoginPrompt: Identifiable, Equatable, Sendable {
        public let userCode: String
        public let verificationURI: URL

        public var id: String { userCode }

        public init(userCode: String, verificationURI: URL) {
            self.userCode = userCode
            self.verificationURI = verificationURI
        }
    }

    @Published public private(set) var state: State = .signedOut
    @Published public private(set) var devicePrompt: DeviceLoginPrompt?

    private let configuration: OAuthConfiguration
    private let tokenStore: OAuthTokenStore
    private let oauthClient: OAuthClient
    private let authorizer: OAuthAuthorizing
    private let stateGenerator: () -> String
    private var loginTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.meeyao.dankchat", category: "Auth")

    public init(
        configuration: OAuthConfiguration,
        tokenStore: OAuthTokenStore,
        oauthClient: OAuthClient,
        authorizer: OAuthAuthorizing,
        stateGenerator: @escaping () -> String = { UUID().uuidString }
    ) {
        self.configuration = configuration
        self.tokenStore = tokenStore
        self.oauthClient = oauthClient
        self.authorizer = authorizer
        self.stateGenerator = stateGenerator
    }

    public func restoreSession() {
        do {
            if let token = try tokenStore.readToken(), !token.isExpired() {
                state = .signedIn(token)
            } else {
                state = .signedOut
            }
        } catch {
            state = .error("Failed to read stored token")
        }
    }

    /// Starts Twitch's device-code login. The prompt is published so the UI can
    /// show the user code and the activation URL while polling runs.
    public func beginLogin() {
        loginTask?.cancel()
        state = .signingIn
        devicePrompt = nil
        loginTask = Task { [weak self] in
            await self?.performDeviceLogin()
        }
    }

    public func cancelLogin() {
        loginTask?.cancel()
        loginTask = nil
        devicePrompt = nil
        state = .signedOut
    }

    private func performDeviceLogin() async {
        do {
            let challenge = try await oauthClient.requestDeviceCode()
            guard !Task.isCancelled else { return }
            guard let verificationURL = URL(string: challenge.verificationURI) else {
                state = .error("Twitch returned an invalid activation link")
                return
            }
            devicePrompt = DeviceLoginPrompt(
                userCode: challenge.userCode,
                verificationURI: verificationURL
            )
            logger.info("Device login started, code \(challenge.userCode, privacy: .public)")

            let deadline = Date().addingTimeInterval(TimeInterval(challenge.expiresIn))
            var interval = UInt64(max(challenge.interval, 1))

            while Date() < deadline {
                try await Task.sleep(nanoseconds: interval * 1_000_000_000)
                guard !Task.isCancelled else { return }

                do {
                    let token = try await oauthClient.pollDeviceToken(deviceCode: challenge.deviceCode)
                    logger.info("Device login token received")
                    do {
                        try tokenStore.writeToken(token)
                    } catch {
                        // A keychain failure must not hide a successful Twitch login.
                        logger.error("Token persistence failed: \(String(describing: error), privacy: .public)")
                    }
                    devicePrompt = nil
                    state = .signedIn(token)
                    return
                } catch OAuthError.authorizationPending {
                    continue
                } catch OAuthError.slowDown {
                    interval += 5
                }
            }

            devicePrompt = nil
            state = .error("Login code expired")
        } catch is CancellationError {
            // The user cancelled; cancelLogin already reset the state.
        } catch {
            logger.error("Device login failed: \(String(describing: error), privacy: .public)")
            devicePrompt = nil
            state = .error("Login failed: \(error.localizedDescription)")
        }
    }

    public func refreshIfNeeded() async {
        guard case let .signedIn(token) = state else { return }
        guard token.shouldRefresh() else { return }
        guard let refreshToken = token.refreshToken else {
            state = .signedOut
            return
        }

        do {
            let refreshed = try await oauthClient.refresh(refreshToken: refreshToken)
            try tokenStore.writeToken(refreshed)
            state = .signedIn(refreshed)
        } catch {
            state = .signedOut
        }
    }

    public func signOut() {
        do {
            try tokenStore.clearToken()
        } catch {
            // Intentionally ignoring cleanup failure.
        }
        state = .signedOut
    }

    private static func extractCode(from url: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw OAuthError.invalidCallback
        }
        let items = components.queryItems ?? []
        let code = items.first(where: { $0.name == "code" })?.value
        let state = items.first(where: { $0.name == "state" })?.value
        guard state == expectedState else {
            throw OAuthError.invalidState
        }
        guard let code else {
            throw OAuthError.invalidCallback
        }
        return code
    }
}
