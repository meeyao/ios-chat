import XCTest
@testable import DankChatCore

final class BackoffPolicyTests: XCTestCase {
    func testBackoffIncreasesUntilMax() {
        let policy = BackoffPolicy(initialDelay: 1, maxDelay: 5, multiplier: 2, jitter: 0)
        let delays = (1...5).map { policy.delay(for: $0) }
        XCTAssertEqual(delays[0], 1)
        XCTAssertEqual(delays[1], 2)
        XCTAssertEqual(delays[2], 4)
        XCTAssertEqual(delays[3], 5)
        XCTAssertEqual(delays[4], 5)
    }
}
