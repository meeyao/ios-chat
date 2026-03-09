import Foundation

public final class TwitchEmoteProvider: @unchecked Sendable {
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

    public func fetchGlobalEmotes() async throws -> [Emote] {
        let response: TwitchEmoteResponse = try await request(
            path: "/helix/chat/emotes/global",
            queryItems: []
        )
        return response.data.compactMap { emote(from: $0) }
    }

    public func fetchChannelEmotes(broadcasterId: String) async throws -> [Emote] {
        let response: TwitchEmoteResponse = try await request(
            path: "/helix/chat/emotes",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
        )
        return response.data.compactMap { emote(from: $0) }
    }

    public func fetchBroadcasterId(login: String) async throws -> String? {
        let response: TwitchUserResponse = try await request(
            path: "/helix/users",
            queryItems: [URLQueryItem(name: "login", value: login)]
        )
        return response.data.first?.id
    }

    private func emote(from data: TwitchEmoteData) -> Emote? {
        guard let imageURLs = resolveImageURLs(for: data) else { return nil }
        let isAnimated = data.format.contains("animated")
        return Emote(
            providerId: data.id,
            code: data.name,
            imageURLs: imageURLs,
            isAnimated: isAnimated,
            provider: .twitch
        )
    }

    private func resolveImageURLs(for data: TwitchEmoteData) -> EmoteImageURLs? {
        if let template = data.template {
            let format = data.format.contains("animated") ? "animated" : "static"
            let theme = "dark"
            let url1x = buildTemplateURL(template, data.id, format, theme, "1.0")
            let url2x = buildTemplateURL(template, data.id, format, theme, "2.0")
            let url3x = buildTemplateURL(template, data.id, format, theme, "3.0")
            guard let url1x else { return nil }
            return EmoteImageURLs(
                url1x: url1x,
                url2x: url2x,
                url3x: url3x,
                preferred: url2x ?? url1x
            )
        }

        if let images = data.images,
           let url1x = URL(string: images.url1x) {
            let url2x = URL(string: images.url2x)
            let url3x = URL(string: images.url4x)
            return EmoteImageURLs(url1x: url1x, url2x: url2x, url3x: url3x, preferred: url2x ?? url1x)
        }

        return nil
    }

    private func buildTemplateURL(
        _ template: String,
        _ id: String,
        _ format: String,
        _ theme: String,
        _ scale: String
    ) -> URL? {
        let urlString = template
            .replacingOccurrences(of: "{id}", with: id)
            .replacingOccurrences(of: "{format}", with: format)
            .replacingOccurrences(of: "{theme_mode}", with: theme)
            .replacingOccurrences(of: "{scale}", with: scale)
        return URL(string: urlString)
    }

    private func request<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        guard let token = await tokenProvider(), !token.isEmpty else {
            throw TwitchEmoteProviderError.missingAccessToken
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.twitch.tv"
        components.path = path
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw TwitchEmoteProviderError.invalidURL
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
            throw TwitchEmoteProviderError.httpError(statusCode: http.statusCode, payload: data)
        }
    }
}

public enum TwitchEmoteProviderError: Error {
    case missingAccessToken
    case invalidURL
    case httpError(statusCode: Int, payload: Data)
}

private struct TwitchEmoteResponse: Decodable {
    let data: [TwitchEmoteData]
}

private struct TwitchEmoteData: Decodable {
    let id: String
    let name: String
    let format: [String]
    let scale: [String]?
    let themeMode: [String]?
    let template: String?
    let images: TwitchEmoteImages?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case format
        case scale
        case themeMode = "theme_mode"
        case template
        case images
    }
}

private struct TwitchEmoteImages: Decodable {
    let url1x: String
    let url2x: String
    let url4x: String

    private enum CodingKeys: String, CodingKey {
        case url1x = "url_1x"
        case url2x = "url_2x"
        case url4x = "url_4x"
    }
}

private struct TwitchUserResponse: Decodable {
    let data: [TwitchUser]
}

private struct TwitchUser: Decodable {
    let id: String
    let login: String
}
