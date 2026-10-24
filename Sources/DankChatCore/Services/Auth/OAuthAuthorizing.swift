import Foundation
#if canImport(AuthenticationServices)
import AuthenticationServices
import UIKit
#endif

public protocol OAuthAuthorizing: Sendable {
    func authorize(authURL: URL, callbackScheme: String) async throws -> URL
}

#if canImport(AuthenticationServices)
@MainActor
public final class SystemOAuthAuthorizer: NSObject, OAuthAuthorizing {
    private var session: ASWebAuthenticationSession?

    public func authorize(authURL: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url else {
                    continuation.resume(throwing: OAuthError.invalidCallback)
                    return
                }
                continuation.resume(returning: url)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            self.session = session
            session.start()
        }
    }
}

extension SystemOAuthAuthorizer: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
#endif
