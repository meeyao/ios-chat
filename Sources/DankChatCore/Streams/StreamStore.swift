import Combine
import Foundation

// MARK: - Model

public struct StreamInfo: Identifiable, Equatable, Sendable {
    public let userLogin: String
    public let viewerCount: Int
    public let startedAt: Date?
    public let gameName: String?
    public let title: String?

    public var id: String { userLogin }

    public init(
        userLogin: String,
        viewerCount: Int,
        startedAt: Date? = nil,
        gameName: String? = nil,
        title: String? = nil
    ) {
        self.userLogin = userLogin
        self.viewerCount = viewerCount
        self.startedAt = startedAt
        self.gameName = gameName
        self.title = title
    }

    public var uptimeText: String {
        guard let startedAt else { return "" }
        let elapsed = max(0, Date().timeIntervalSince(startedAt))
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    public func summary(showCategory: Bool) -> String {
        var parts = ["\(viewerCount) viewers"]
        let uptime = uptimeText
        if !uptime.isEmpty {
            parts.append(uptime)
        }
        if showCategory, let gameName, !gameName.isEmpty {
            parts.append(gameName)
        }
        return parts.joined(separator: " · ")
    }
}

public struct StreamSettings: Codable, Equatable, Sendable {
    public var fetchStreams: Bool
    public var showStreamInfo: Bool
    public var showStreamCategory: Bool
    public var preventStreamReloads: Bool
    public var enablePiP: Bool

    public init(
        fetchStreams: Bool = true,
        showStreamInfo: Bool = true,
        showStreamCategory: Bool = false,
        preventStreamReloads: Bool = true,
        enablePiP: Bool = false
    ) {
        self.fetchStreams = fetchStreams
        self.showStreamInfo = showStreamInfo
        self.showStreamCategory = showStreamCategory
        self.preventStreamReloads = preventStreamReloads
        self.enablePiP = enablePiP
    }
}

// MARK: - Helix

public final class HelixStreamsService: @unchecked Sendable {
    private let client: HelixAPIClient

    public init(client: HelixAPIClient) {
        self.client = client
    }

    public func getStreams(logins: [String]) async throws -> [StreamInfo] {
        let unique = Array(Set(logins.map { $0.lowercased() })).sorted()
        guard !unique.isEmpty else { return [] }

        let response: StreamsResponse = try await client.execute(
            HelixRequest(
                path: "/streams",
                queryItems: unique.map { URLQueryItem(name: "user_login", value: $0) }
            )
        )

        return response.data.map {
            StreamInfo(
                userLogin: $0.userLogin,
                viewerCount: $0.viewerCount,
                startedAt: Self.parseDate($0.startedAt),
                gameName: $0.gameName,
                title: $0.title
            )
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private struct StreamsResponse: Decodable {
        let data: [StreamDTO]
    }

    private struct StreamDTO: Decodable {
        let userLogin: String
        let viewerCount: Int
        let startedAt: String
        let gameName: String?
        let title: String?
    }
}

// MARK: - Store

/// Polls Helix for live stream info for the joined channels.
@MainActor
public final class StreamStore: ObservableObject {
    @Published public private(set) var streams: [String: StreamInfo] = [:]
    @Published public var settings: StreamSettings {
        didSet {
            saveSettings()
            if !settings.fetchStreams {
                refreshTask?.cancel()
                streams = [:]
            } else {
                updateChannels(watchedLogins)
            }
        }
    }

    private let service: HelixStreamsService
    private let defaults: UserDefaults
    private let settingsKey = "streams.settings.v1"
    private var watchedLogins: [String] = []
    private var refreshTask: Task<Void, Never>?

    public init(service: HelixStreamsService, defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        if let data = defaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(StreamSettings.self, from: data) {
            settings = decoded
        } else {
            settings = StreamSettings()
        }
    }

    public func updateChannels(_ logins: [String]) {
        let normalized = Array(Set(logins.map { $0.lowercased() })).sorted()
        guard normalized != watchedLogins else { return }
        watchedLogins = normalized
        refreshTask?.cancel()
        guard settings.fetchStreams, !normalized.isEmpty else {
            streams = [:]
            return
        }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    public func refresh() async {
        guard settings.fetchStreams, !watchedLogins.isEmpty else { return }
        do {
            let results = try await service.getStreams(logins: watchedLogins)
            var next: [String: StreamInfo] = [:]
            for item in results {
                next[item.userLogin.lowercased()] = item
            }
            streams = next
        } catch {
            // An unauthenticated or offline refresh simply keeps the last snapshot.
        }
    }

    public func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        streams = [:]
    }

    private func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: settingsKey)
    }
}
