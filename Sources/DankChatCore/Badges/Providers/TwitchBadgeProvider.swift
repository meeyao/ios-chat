import Foundation

public final class TwitchBadgeProvider: @unchecked Sendable {
    private let configuration: OAuthConfiguration
    private let tokenProvider: () async -> String?
    private let urlSession: URLSession

    public init(
        configuration: OAuthConfiguration,
        tokenProvider: @escaping () async -> String?,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.tokenProvider = tokenProvider
        self.urlSession = urlSession
    }

    public func fetchGlobalBadges() async throws -> [Badge] {
        let response: TwitchBadgeResponse = try await request(
            path: "/helix/chat/badges/global",
            queryItems: []
        )
        return response.data.flatMap { mapSet($0) }
    }

    public func fetchChannelBadges(broadcasterId: String) async throws -> [Badge] {
        let response: TwitchBadgeResponse = try await request(
            path: "/helix/chat/badges",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
        )
        return response.data.flatMap { mapSet($0) }
    }

    public func fetchBroadcasterId(login: String) async throws -> String? {
        let response: TwitchUserResponse = try await request(
            path: "/helix/users",
            queryItems: [URLQueryItem(name: "login", value: login)]
        )
        return response.data.first?.id
    }

    private func mapSet(_ set: TwitchBadgeSet) -> [Badge] {
        set.versions.compactMap { version in
            guard let url1x = URL(string: version.imageURL1x) else { return nil }
            let url2x = URL(string: version.imageURL2x)
            let url4x = URL(string: version.imageURL4x)
            let imageURLs = BadgeImageURLs(url1x: url1x, url2x: url2x, url4x: url4x, preferred: url2x ?? url1x)
            return Badge(
                badgeId: set.setId,
                version: version.id,
                title: version.title,
                imageURLs: imageURLs,
                provider: .twitch
            )
        }
    }

    private func request<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        guard let token = await tokenProvider(), !token.isEmpty else {
            throw TwitchBadgeProviderError.missingAccessToken
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.twitch.tv"
        components.path = path
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw TwitchBadgeProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(configuration.clientId, forHTTPHeaderField: "Client-Id")

        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw TwitchBadgeProviderError.httpError(statusCode: http.statusCode, payload: data)
        }
    }
}

public enum TwitchBadgeProviderError: Error {
    case missingAccessToken
    case invalidURL
    case httpError(statusCode: Int, payload: Data)
}

private struct TwitchBadgeResponse: Decodable {
    let data: [TwitchBadgeSet]
}

private struct TwitchBadgeSet: Decodable {
    let setId: String
    let versions: [TwitchBadgeVersion]

    private enum CodingKeys: String, CodingKey {
        case setId = "set_id"
        case versions
    }
}

private struct TwitchBadgeVersion: Decodable {
    let id: String
    let imageURL1x: String
    let imageURL2x: String
    let imageURL4x: String
    let title: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case imageURL1x = "image_url_1x"
        case imageURL2x = "image_url_2x"
        case imageURL4x = "image_url_4x"
        case title
    }
}

private struct TwitchUserResponse: Decodable {
    let data: [TwitchUser]
}

private struct TwitchUser: Decodable {
    let id: String
    let login: String
}
