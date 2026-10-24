import XCTest
@testable import DankChatCore

final class IRCCommandRateLimiterTests: XCTestCase {
    func testLimiterAllowsBurstThenWaits() async {
        let limiter = IRCCommandRateLimiter(capacity: 2, refillInterval: 0.2)
        let start = Date()
        await limiter.acquire()
        await limiter.acquire()
        await limiter.acquire()
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThanOrEqual(elapsed, 0.15)
    }
}
