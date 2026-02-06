import Combine
import Foundation

@MainActor
public final class EmoteStore: ObservableObject {
    public struct RefreshIntervals: Sendable {
        public let bttv: TimeInterval
        public let ffz: TimeInterval

        public init(bttv: TimeInterval, ffz: TimeInterval) {
            self.bttv = bttv
            self.ffz = ffz
        }

        public static let `default` = RefreshIntervals(bttv: 900, ffz: 900)
    }

    @Published public private(set) var globalEmotes: [ProviderID: [Emote]] = [:]
    @Published public private(set) var channelEmotes: [String: [ProviderID: [Emote]]] = [:]

    private let twitchProvider: TwitchEmoteProvider
    private let bttvProvider: BTTVEmoteProvider
    private let ffzProvider: FFZEmoteProvider
    private let sevenTVProvider: SevenTVEmoteProvider
    private let providerStatus: ProviderStatusStore?
    private let refreshIntervals: RefreshIntervals

    private var globalRefreshTask: Task<Void, Never>?
    private var channelRefreshTasks: [String: [ProviderID: Task<Void, Never>]] = [:]
    private var broadcasterIdCache: [String: String] = [:]

    private var twitchEmotesByIdGlobal: [String: Emote] = [:]
    private var twitchEmotesByIdChannel: [String: [String: Emote]] = [:]

    private let precedence: [ProviderID] = [.twitch, .sevenTV, .bttv, .ffz]

    public init(
        twitchProvider: TwitchEmoteProvider,
        bttvProvider: BTTVEmoteProvider,
        ffzProvider: FFZEmoteProvider,
        sevenTVProvider: SevenTVEmoteProvider,
        providerStatus: ProviderStatusStore? = nil,
        refreshIntervals: RefreshIntervals = .default
    ) {
        self.twitchProvider = twitchProvider
        self.bttvProvider = bttvProvider
        self.ffzProvider = ffzProvider
        self.sevenTVProvider = sevenTVProvider
        self.providerStatus = providerStatus
        self.refreshIntervals = refreshIntervals

        globalRefreshTask = Task { [weak self] in
            await self?.refreshGlobalEmotes()
        }
    }

    deinit {
        globalRefreshTask?.cancel()
        for tasks in channelRefreshTasks.values {
            for task in tasks.values {
                task.cancel()
            }
        }
    }

    public func refreshGlobalEmotes() async {
        await refreshGlobalEmotes(for: .twitch) {
            try await twitchProvider.fetchGlobalEmotes()
        }
        await refreshGlobalEmotes(for: .bttv) {
            try await bttvProvider.fetchGlobalEmotes()
        }
        await refreshGlobalEmotes(for: .ffz) {
            try await ffzProvider.fetchGlobalEmotes()
        }
        await refreshGlobalEmotes(for: .sevenTV) {
            try await sevenTVProvider.fetchGlobalEmotes()
        }
    }

    public func loadChannelEmotes(channelLogin: String) async {
        let normalized = normalizeChannel(channelLogin)
        guard !normalized.isEmpty else { return }

        let broadcasterId = await resolveBroadcasterId(login: normalized)

        await refreshChannelEmotes(
            for: normalized,
            provider: .twitch,
            fetch: {
                guard let broadcasterId else { return [] }
                return try await twitchProvider.fetchChannelEmotes(broadcasterId: broadcasterId)
            }
        )

        await refreshChannelEmotes(
            for: normalized,
            provider: .bttv,
            fetch: {
                guard let broadcasterId else { return [] }
                return try await bttvProvider.fetchChannelEmotes(broadcasterId: broadcasterId)
            }
        )

        await refreshChannelEmotes(
            for: normalized,
            provider: .ffz,
            fetch: {
                try await ffzProvider.fetchChannelEmotes(channelLogin: normalized)
            }
        )

        await refreshChannelEmotes(
            for: normalized,
            provider: .sevenTV,
            fetch: {
                guard let broadcasterId else { return [] }
                return try await sevenTVProvider.fetchChannelEmotes(broadcasterId: broadcasterId)
            }
        )

        schedulePeriodicRefresh(for: normalized)
    }

    public func emotes(for provider: ProviderID, channelLogin: String?) -> [Emote] {
        let global = globalEmotes[provider] ?? []
        guard let channelLogin else { return global }
        let normalized = normalizeChannel(channelLogin)
        let channel = channelEmotes[normalized]?[provider] ?? []
        return mergeByProviderId(global, channel)
    }

    public func resolveEmote(code: String, channelLogin: String?) -> Emote? {
        let normalized = channelLogin.map(normalizeChannel)
        let candidates = mergedEmotes(channelLogin: normalized)
        return candidates[code]
    }

    public func resolveTwitchEmote(occurrence: TwitchEmoteOccurrence, channelLogin: String?) -> Emote? {
        if let channelLogin {
            let normalized = normalizeChannel(channelLogin)
            if let channelMap = twitchEmotesByIdChannel[normalized], let emote = channelMap[occurrence.emoteId] {
                return emote
            }
        }
        return twitchEmotesByIdGlobal[occurrence.emoteId]
    }

    public func preferredImageURL(for emote: Emote, allowAnimated: Bool) -> URL {
        if allowAnimated || !emote.isAnimated {
            return emote.imageURLs.preferred
        }
        return emote.imageURLs.fallback ?? emote.imageURLs.url1x
    }

    private func refreshGlobalEmotes(for provider: ProviderID, fetch: () async throws -> [Emote]) async {
        do {
            let emotes = try await fetch()
            globalEmotes[provider] = emotes
            if provider == .twitch {
                twitchEmotesByIdGlobal = Dictionary(uniqueKeysWithValues: emotes.map { ($0.providerId, $0) })
            }
        } catch {
            recordOutage(provider: provider, message: "Failed to refresh global emotes.")
        }
    }

    private func refreshChannelEmotes(
        for channelLogin: String,
        provider: ProviderID,
        fetch: () async throws -> [Emote]
    ) async {
        do {
            let emotes = try await fetch()
            var providerMap = channelEmotes[channelLogin] ?? [:]
            providerMap[provider] = emotes
            channelEmotes[channelLogin] = providerMap
            if provider == .twitch {
                twitchEmotesByIdChannel[channelLogin] = Dictionary(uniqueKeysWithValues: emotes.map { ($0.providerId, $0) })
            }
        } catch {
            recordOutage(provider: provider, message: "Failed to refresh \(channelLogin) emotes.")
        }
    }

    private func schedulePeriodicRefresh(for channelLogin: String) {
        var tasks = channelRefreshTasks[channelLogin] ?? [:]
        if tasks[.bttv] == nil {
            tasks[.bttv] = Task { [weak self] in
                await self?.repeatRefresh(
                    interval: self?.refreshIntervals.bttv ?? 900,
                    channelLogin: channelLogin,
                    provider: .bttv
                )
            }
        }
        if tasks[.ffz] == nil {
            tasks[.ffz] = Task { [weak self] in
                await self?.repeatRefresh(
                    interval: self?.refreshIntervals.ffz ?? 900,
                    channelLogin: channelLogin,
                    provider: .ffz
                )
            }
        }
        channelRefreshTasks[channelLogin] = tasks
    }

    private func repeatRefresh(interval: TimeInterval, channelLogin: String, provider: ProviderID) async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            } catch {
                return
            }
            await refreshPeriodic(channelLogin: channelLogin, provider: provider)
        }
    }

    private func refreshPeriodic(channelLogin: String, provider: ProviderID) async {
        switch provider {
        case .bttv:
            let broadcasterId = await resolveBroadcasterId(login: channelLogin)
            await refreshChannelEmotes(
                for: channelLogin,
                provider: .bttv,
                fetch: {
                    guard let broadcasterId else { return [] }
                    return try await bttvProvider.fetchChannelEmotes(broadcasterId: broadcasterId)
                }
            )
        case .ffz:
            await refreshChannelEmotes(
                for: channelLogin,
                provider: .ffz,
                fetch: {
                    try await ffzProvider.fetchChannelEmotes(channelLogin: channelLogin)
                }
            )
        default:
            break
        }
    }

    private func mergedEmotes(channelLogin: String?) -> [String: Emote] {
        var merged: [String: Emote] = [:]
        for provider in precedence {
            let emotes = emotes(for: provider, channelLogin: channelLogin)
            for emote in emotes {
                if merged[emote.code] == nil {
                    merged[emote.code] = emote
                }
            }
        }
        return merged
    }

    private func mergeByProviderId(_ global: [Emote], _ channel: [Emote]) -> [Emote] {
        var seen: Set<String> = []
        var merged: [Emote] = []
        for emote in global + channel {
            guard !seen.contains(emote.providerId) else { continue }
            seen.insert(emote.providerId)
            merged.append(emote)
        }
        return merged
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

    private func recordOutage(provider: ProviderID, message: String) {
        providerStatus?.recordOutage(provider: provider, message: message)
    }

    private func normalizeChannel(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
