import Foundation

public actor IRCCommandRateLimiter {
    private let capacity: Int
    private let refillInterval: TimeInterval
    private var tokens: Int
    private var lastRefill: Date

    public init(capacity: Int = 20, refillInterval: TimeInterval = 10) {
        self.capacity = capacity
        self.refillInterval = refillInterval
        self.tokens = capacity
        self.lastRefill = Date()
    }

    public func acquire() async {
        while true {
            refillIfNeeded(now: Date())
            if tokens > 0 {
                tokens -= 1
                return
            }
            let nextRefill = lastRefill.addingTimeInterval(refillInterval)
            let sleepDuration = max(0.1, nextRefill.timeIntervalSinceNow)
            try? await Task.sleep(nanoseconds: UInt64(sleepDuration * 1_000_000_000))
        }
    }

    private func refillIfNeeded(now: Date) {
        guard now.timeIntervalSince(lastRefill) >= refillInterval else { return }
        tokens = capacity
        lastRefill = now
    }
}
