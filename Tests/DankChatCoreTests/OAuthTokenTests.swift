import XCTest
@testable import DankChatCore

final class OAuthTokenTests: XCTestCase {
    func testExpiredToken() {
        let token = OAuthToken(
            accessToken: "token",
            refreshToken: "refresh",
            scope: ["chat:read"],
            tokenType: "bearer",
            expiresAt: Date().addingTimeInterval(-10)
        )
        XCTAssertTrue(token.isExpired())
    }

    func testShouldRefreshWithLeeway() {
        let token = OAuthToken(
            accessToken: "token",
            refreshToken: "refresh",
            scope: ["chat:read"],
            tokenType: "bearer",
            expiresAt: Date().addingTimeInterval(30)
        )
        XCTAssertTrue(token.shouldRefresh(leeway: 60))
    }
}
