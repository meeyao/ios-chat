import Foundation

@available(macOS 12.0, iOS 15.0, *)
@MainActor
public final class EmoteRecentsStore: ObservableObject {
    public struct Entry: Identifiable, Codable, Equatable {
        public let id: String
        public var providerId: String
        public var provider: ProviderID
        public var code: String
        public var imageURL1x: String
        public var imageURL2x: String?
        public var imageURL3x: String?
        public var imageURL4x: String?
        public var preferredURL: String
        public var fallbackURL: String?
        public var isAnimated: Bool
        public var lastUsed: Date
        public var useCount: Int
    }

    @Published public private(set) var entries: [Entry] = []

    private let limit: Int
    private let storage: UserDefaults
    private let entriesKey = "emoteRecents.entries"

    public init(limit: Int = 20, storage: UserDefaults = .standard) {
        self.limit = limit
        self.storage = storage
        self.entries = loadEntries()
    }

    public func recordUse(emote: Emote) {
        let now = Date()
        if let index = entries.firstIndex(where: { $0.id == emote.id }) {
            var entry = entries[index]
            entry.code = emote.code
            entry.providerId = emote.providerId
            entry.provider = emote.provider
            entry.isAnimated = emote.isAnimated
            entry.imageURL1x = emote.imageURLs.url1x.absoluteString
            entry.imageURL2x = emote.imageURLs.url2x?.absoluteString
            entry.imageURL3x = emote.imageURLs.url3x?.absoluteString
            entry.imageURL4x = emote.imageURLs.url4x?.absoluteString
            entry.preferredURL = emote.imageURLs.preferred.absoluteString
            entry.fallbackURL = emote.imageURLs.fallback?.absoluteString
            entry.lastUsed = now
            entry.useCount += 1
            entries[index] = entry
        } else {
            let entry = Entry(
                id: emote.id,
                providerId: emote.providerId,
                provider: emote.provider,
                code: emote.code,
                imageURL1x: emote.imageURLs.url1x.absoluteString,
                imageURL2x: emote.imageURLs.url2x?.absoluteString,
                imageURL3x: emote.imageURLs.url3x?.absoluteString,
                imageURL4x: emote.imageURLs.url4x?.absoluteString,
                preferredURL: emote.imageURLs.preferred.absoluteString,
                fallbackURL: emote.imageURLs.fallback?.absoluteString,
                isAnimated: emote.isAnimated,
                lastUsed: now,
                useCount: 1
            )
            entries.append(entry)
        }

        trimAndPersist()
    }

    public func recordEmotes(in message: String, emoteStore: EmoteStore, channelLogin: String?) {
        let tokens = message.split(whereSeparator: { $0.isWhitespace })
        for token in tokens {
            let cleaned = token.trimmingCharacters(in: .punctuationCharacters)
            guard !cleaned.isEmpty else { continue }
            if let emote = emoteStore.resolveEmote(code: String(cleaned), channelLogin: channelLogin) {
                recordUse(emote: emote)
            }
        }
    }

    public func orderedRecents(ordering: EmoteMenuSettings.RecentsOrdering) -> [Emote] {
        let sorted: [Entry]
        switch ordering {
        case .mostRecent:
            sorted = entries.sorted { lhs, rhs in
                if lhs.lastUsed == rhs.lastUsed {
                    return lhs.useCount > rhs.useCount
                }
                return lhs.lastUsed > rhs.lastUsed
            }
        case .mostUsed:
            sorted = entries.sorted { lhs, rhs in
                if lhs.useCount == rhs.useCount {
                    return lhs.lastUsed > rhs.lastUsed
                }
                return lhs.useCount > rhs.useCount
            }
        }

        return sorted.compactMap { entry in
            guard let url1x = URL(string: entry.imageURL1x),
                  let preferred = URL(string: entry.preferredURL) else {
                return nil
            }

            let imageURLs = EmoteImageURLs(
                url1x: url1x,
                url2x: entry.imageURL2x.flatMap(URL.init),
                url3x: entry.imageURL3x.flatMap(URL.init),
                url4x: entry.imageURL4x.flatMap(URL.init),
                preferred: preferred,
                fallback: entry.fallbackURL.flatMap(URL.init)
            )
            return Emote(
                providerId: entry.providerId,
                code: entry.code,
                imageURLs: imageURLs,
                isAnimated: entry.isAnimated,
                provider: entry.provider
            )
        }
    }

    private func trimAndPersist() {
        if entries.count > limit {
            entries = entries
                .sorted { $0.lastUsed > $1.lastUsed }
                .prefix(limit)
                .map { $0 }
        }
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(entries)
            storage.set(data, forKey: entriesKey)
        } catch {
            return
        }
    }

    private func loadEntries() -> [Entry] {
        guard let data = storage.data(forKey: entriesKey) else { return [] }
        do {
            return try JSONDecoder().decode([Entry].self, from: data)
        } catch {
            return []
        }
    }
}
