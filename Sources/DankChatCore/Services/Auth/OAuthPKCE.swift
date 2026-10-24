import CryptoKit
import Foundation

public struct OAuthPKCE: Sendable {
    public let codeVerifier: String
    public let codeChallenge: String

    public init(codeVerifier: String, codeChallenge: String) {
        self.codeVerifier = codeVerifier
        self.codeChallenge = codeChallenge
    }

    public static func generate() -> OAuthPKCE {
        let verifier = Self.randomString(length: 64)
        let challenge = Self.base64URLEncode(data: SHA256.hash(data: Data(verifier.utf8)))
        return OAuthPKCE(codeVerifier: verifier, codeChallenge: challenge)
    }

    private static func randomString(length: Int) -> String {
        let charset = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        var result = String()
        result.reserveCapacity(length)
        for _ in 0..<length {
            result.append(charset[Int.random(in: 0..<charset.count)])
        }
        return result
    }

    private static func base64URLEncode(data: SHA256.Digest) -> String {
        return Data(data)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
