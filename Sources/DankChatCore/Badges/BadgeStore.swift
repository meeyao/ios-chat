import Combine
import Foundation

public struct BadgeImageURLs: Equatable, Sendable {
    public let url1x: URL
    public let url2x: URL?
    public let url4x: URL?
    public let preferred: URL

    public init(url1x: URL, url2x: URL? = nil, url4x: URL? = nil, preferred: URL? = nil) {
        self.url1x = url1x
        self.url2x = url2x
        self.url4x = url4x
        self.preferred = preferred ?? url2x ?? url1x
    }
}

public struct Badge: Identifiable, Equatable, Sendable {
    public let id: String
    public let badgeId: String
    public let version: String
    public let title: String?
    public let imageURLs: BadgeImageURLs
    public let provider: ProviderID

    public init(
        badgeId: String,
        version: String,
        title: String?,
        imageURLs: BadgeImageURLs,
        provider: ProviderID
    ) {
        self.badgeId = badgeId
        self.version = version
        self.title = title
        self.imageURLs = imageURLs
        self.provider = provider
        self.id = "\(provider.rawValue):\(badgeId):\(version)"
    }
}

@available(macOS 12.0, iOS 15.0, *)
@MainActor
public final class BadgeStore: ObservableObject {
    @Published public private(set) var globalBadges: [ProviderID: [Badge]] = [:]
    @Published public private(set) var channelBadges: [String: [ProviderID: [Badge]]] = [:]

    private let twitchProvider: TwitchBadgeProvider
    private let providerStatus: ProviderStatusStore?
    private var broadcasterIdCache: [String: String] = [:]
    private var twitchBadgesByIdGlobal: [String: Badge] = [:]
    private var twitchBadgesByIdChannel: [String: [String: Badge]] = [:]

    public init(twitchProvider: TwitchBadgeProvider, providerStatus: ProviderStatusStore? = nil) {
        self.twitchProvider = twitchProvider
        self.providerStatus = providerStatus

        Task { [weak self] in
            await self?.refreshGlobalBadges()
        }
    }

    public func refreshGlobalBadges() async {
        do {
            let badges = try await twitchProvider.fetchGlobalBadges()
            globalBadges[.twitch] = badges
            twitchBadgesByIdGlobal = Dictionary(uniqueKeysWithValues: badges.map { (badgeKey($0), $0) })
        } catch {
            recordOutage(provider: .twitch, message: "Failed to refresh global badges.")
        }
    }

    public func loadChannelBadges(channelLogin: String) async {
        let normalized = normalizeChannel(channelLogin)
        guard !normalized.isEmpty else { return }

        let broadcasterId = await resolveBroadcasterId(login: normalized)
        do {
            guard let broadcasterId else { return }
            let badges = try await twitchProvider.fetchChannelBadges(broadcasterId: broadcasterId)
            var providerMap = channelBadges[normalized] ?? [:]
            providerMap[.twitch] = badges
            channelBadges[normalized] = providerMap
            twitchBadgesByIdChannel[normalized] = Dictionary(uniqueKeysWithValues: badges.map { (badgeKey($0), $0) })
        } catch {
            recordOutage(provider: .twitch, message: "Failed to refresh \(normalized) badges.")
        }
    }

    public func resolveBadges(for message: ChatMessage) -> [Badge] {
        resolveBadges(for: message.badgeTags, channelLogin: message.channel)
    }

    public func resolveBadges(for tags: [TwitchBadgeTag], channelLogin: String?) -> [Badge] {
        let normalized = channelLogin.map(normalizeChannel)
        let channelMap = normalized.flatMap { twitchBadgesByIdChannel[$0] } ?? [:]
        return tags.compactMap { tag in
            let key = badgeKey(tag.id, tag.version)
            return channelMap[key] ?? twitchBadgesByIdGlobal[key]
        }
    }

    public func availableBadgeCategories() -> [ProviderID: [String]] {
        var categorySets: [ProviderID: Set<String>] = [:]

        for (provider, badges) in globalBadges {
            var existing = categorySets[provider] ?? []
            for badge in badges {
                existing.insert(badge.badgeId)
            }
            categorySets[provider] = existing
        }

        for (_, providerMap) in channelBadges {
            for (provider, badges) in providerMap {
                var existing = categorySets[provider] ?? []
                for badge in badges {
                    existing.insert(badge.badgeId)
                }
                categorySets[provider] = existing
            }
        }

        return Dictionary(uniqueKeysWithValues: categorySets.map { provider, categories in
            (provider, categories.sorted())
        })
    }

    private func resolveBroadcasterId(login: String) async -> String? {
        if let cached = broadcasterIdCache[login] {
            return cached
        }
        do {
            if let resolved = try await twitchProvider.fetchBroadcasterId(login: login) {
                broadcasterIdCache[login] = resolved
                return resolved
            }
        } catch {
            recordOutage(provider: .twitch, message: "Failed to resolve broadcaster id for \(login).")
        }
        return nil
    }

    private func badgeKey(_ badge: Badge) -> String {
        badgeKey(badge.badgeId, badge.version)
    }

    private func badgeKey(_ id: String, _ version: String) -> String {
        "\(id):\(version)"
    }

    private func recordOutage(provider: ProviderID, message: String) {
        providerStatus?.recordOutage(provider: provider, message: message)
    }

    private func normalizeChannel(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
