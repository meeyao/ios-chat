import Foundation

public actor JoinQueue {
    private var pending: [String] = []
    private var isProcessing = false
    private let rateLimiter: IRCCommandRateLimiter
    private let sendJoin: @Sendable (String) async -> Void

    public init(rateLimiter: IRCCommandRateLimiter, sendJoin: @escaping @Sendable (String) async -> Void) {
        self.rateLimiter = rateLimiter
        self.sendJoin = sendJoin
    }

    public func enqueue(_ channel: String) {
        let normalized = channel.lowercased()
        guard !pending.contains(normalized) else { return }
        pending.append(normalized)
        if !isProcessing {
            isProcessing = true
            Task { await processQueue() }
        }
    }

    public func reset() {
        pending.removeAll()
        isProcessing = false
    }

    private func processQueue() async {
        while !pending.isEmpty {
            let channel = pending.removeFirst()
            await rateLimiter.acquire()
            await sendJoin(channel)
        }
        isProcessing = false
    }
}
