import Combine
import Foundation

public final class ChatStore: ObservableObject {
    @Published public private(set) var entries: [ChatEvent] = []

    private let settings: ChatSettings
    private var messageIds: [String] = []
    private var messageIdSet: Set<String> = []
    private var cancellables: Set<AnyCancellable> = []

    public init(settings: ChatSettings) {
        self.settings = settings
        settings.$scrollbackLimit
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.trimToScrollbackLimit()
            }
            .store(in: &cancellables)
    }

    public func append(event: ChatEvent) {
        if let messageId = event.messageId {
            if messageIdSet.contains(messageId) {
                return
            }
            messageIdSet.insert(messageId)
            messageIds.append(messageId)
        }

        insertEvent(event)
        trimToScrollbackLimit()
    }

    public func clear() {
        entries.removeAll()
        messageIds.removeAll()
        messageIdSet.removeAll()
    }

    private func insertEvent(_ event: ChatEvent) {
        guard !entries.isEmpty else {
            entries.append(event)
            return
        }

        if let index = entries.lastIndex(where: { $0.timestamp <= event.timestamp }) {
            entries.insert(event, at: entries.index(after: index))
        } else {
            entries.insert(event, at: entries.startIndex)
        }
    }

    private func trimToScrollbackLimit() {
        let limit = max(settings.scrollbackLimit, 0)
        guard limit > 0 else {
            clear()
            return
        }

        while entries.count > limit {
            let removed = entries.removeFirst()
            if let messageId = removed.messageId, let index = messageIds.firstIndex(of: messageId) {
                messageIds.remove(at: index)
                messageIdSet.remove(messageId)
            }
        }
    }
}
