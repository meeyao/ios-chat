import Combine
import Foundation

public final class ChannelStore: ObservableObject {
    @Published public private(set) var channels: [Channel] = []
    @Published public private(set) var activeChannelId: String?

    private let settings: ChatSettings
    private var stores: [String: ChatStore] = [:]
    private var states: [String: ChannelState] = [:]

    public init(settings: ChatSettings) {
        self.settings = settings
    }

    public func addChannel(name: String) {
        let normalizedId = Self.normalizeId(name)
        guard !normalizedId.isEmpty else { return }
        if channels.contains(where: { $0.id == normalizedId }) {
            setActive(id: normalizedId)
            return
        }

        let displayName = Channel.displayName(from: name)
        let order = nextUnpinnedSortOrder()
        let channel = Channel(id: normalizedId, displayName: displayName, isPinned: false, sortOrder: order)
        channels.append(channel)
        if states[normalizedId] == nil {
            states[normalizedId] = ChannelState()
        }
        if activeChannelId == nil {
            activeChannelId = normalizedId
        }
        sortChannels()
    }

    public func removeChannel(id: String) {
        let normalizedId = Self.normalizeId(id)
        guard !normalizedId.isEmpty else { return }
        channels.removeAll { $0.id == normalizedId }
        if activeChannelId == normalizedId {
            activeChannelId = channels.first?.id
        }
    }

    public func renameChannel(id: String, newName: String) {
        let normalizedId = Self.normalizeId(id)
        let normalizedNewId = Self.normalizeId(newName)
        guard !normalizedId.isEmpty, !normalizedNewId.isEmpty else { return }
        guard normalizedId != normalizedNewId else {
            updateDisplayName(for: normalizedId, name: newName)
            return
        }
        guard !channels.contains(where: { $0.id == normalizedNewId }) else { return }
        guard let index = channels.firstIndex(where: { $0.id == normalizedId }) else { return }

        var channel = channels[index]
        channel = Channel(
            id: normalizedNewId,
            displayName: Channel.displayName(from: newName),
            isPinned: channel.isPinned,
            sortOrder: channel.sortOrder
        )
        channels[index] = channel

        if let store = stores.removeValue(forKey: normalizedId) {
            stores[normalizedNewId] = store
        }
        if let state = states.removeValue(forKey: normalizedId) {
            states[normalizedNewId] = state
        }
        if activeChannelId == normalizedId {
            activeChannelId = normalizedNewId
        }
        sortChannels()
    }

    public func setPinned(id: String, isPinned: Bool) {
        let normalizedId = Self.normalizeId(id)
        guard let index = channels.firstIndex(where: { $0.id == normalizedId }) else { return }
        var channel = channels[index]
        guard channel.isPinned != isPinned else { return }
        channel.isPinned = isPinned
        if isPinned {
            channel.sortOrder = nextPinnedSortOrder()
        } else {
            channel.sortOrder = nextUnpinnedSortOrder()
        }
        channels[index] = channel
        sortChannels()
    }

    public func moveUnpinned(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        var unpinned = channels.filter { !$0.isPinned }
        move(&unpinned, fromOffsets: offsets, toOffset: destination)
        for (index, channel) in unpinned.enumerated() {
            updateSortOrder(for: channel.id, order: index)
        }
        sortChannels()
    }

    public func setActive(id: String) {
        let normalizedId = Self.normalizeId(id)
        guard channels.contains(where: { $0.id == normalizedId }) else { return }
        activeChannelId = normalizedId
    }

    public func store(for id: String) -> ChatStore {
        let normalizedId = Self.normalizeId(id)
        if let store = stores[normalizedId] {
            return store
        }
        let store = ChatStore(settings: settings)
        stores[normalizedId] = store
        if states[normalizedId] == nil {
            states[normalizedId] = ChannelState()
        }
        return store
    }

    public func state(for id: String) -> ChannelState? {
        let normalizedId = Self.normalizeId(id)
        return states[normalizedId]
    }

    public func updateState(_ state: ChannelState, for id: String) {
        let normalizedId = Self.normalizeId(id)
        guard !normalizedId.isEmpty else { return }
        states[normalizedId] = state
    }

    public func hasHistory(id: String) -> Bool {
        let normalizedId = Self.normalizeId(id)
        guard let store = stores[normalizedId] else { return false }
        return !store.entries.isEmpty
    }

    private func updateDisplayName(for id: String, name: String) {
        guard let index = channels.firstIndex(where: { $0.id == id }) else { return }
        var channel = channels[index]
        channel.displayName = Channel.displayName(from: name)
        channels[index] = channel
    }

    private func updateSortOrder(for id: String, order: Int) {
        guard let index = channels.firstIndex(where: { $0.id == id }) else { return }
        var channel = channels[index]
        channel.sortOrder = order
        channels[index] = channel
    }

    private func sortChannels() {
        channels.sort {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.sortOrder < $1.sortOrder
        }
    }

    private func nextPinnedSortOrder() -> Int {
        let maxOrder = channels.filter { $0.isPinned }.map { $0.sortOrder }.max() ?? -1
        return maxOrder + 1
    }

    private func nextUnpinnedSortOrder() -> Int {
        let maxOrder = channels.filter { !$0.isPinned }.map { $0.sortOrder }.max() ?? -1
        return maxOrder + 1
    }

    private static func normalizeId(_ input: String) -> String {
        Channel.normalizeId(input)
    }

    private func move<T>(_ array: inout [T], fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let moving = offsets.sorted(by: >).map { array.remove(at: $0) }
        let insertionIndex = min(destination, array.count)
        array.insert(contentsOf: moving.reversed(), at: insertionIndex)
    }
}
