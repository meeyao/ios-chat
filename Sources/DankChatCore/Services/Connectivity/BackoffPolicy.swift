import Foundation

public struct BackoffPolicy: Sendable {
    public let initialDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let multiplier: Double
    public let jitter: Double

    public init(
        initialDelay: TimeInterval = 1,
        maxDelay: TimeInterval = 30,
        multiplier: Double = 2,
        jitter: Double = 0.2
    ) {
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
        self.jitter = jitter
    }

    public func delay(for attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        let base = min(maxDelay, initialDelay * pow(multiplier, Double(attempt - 1)))
        let jitterRange = base * jitter
        let jittered = base + Double.random(in: -jitterRange...jitterRange)
        return max(0, jittered)
    }
}
