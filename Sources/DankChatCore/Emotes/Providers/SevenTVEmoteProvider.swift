import Foundation

public final class SevenTVEmoteProvider: @unchecked Sendable {
    private let urlSession: URLSession

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    public func fetchGlobalEmotes() async throws -> [Emote] {
        let url = URL(string: "https://7tv.io/v3/emote-sets/global")!
        let response: SevenTVEmoteSetResponse = try await request(url: url)
        return response.emotes.compactMap { emote(from: $0) }
    }

    public func fetchChannelEmotes(broadcasterId: String) async throws -> [Emote] {
        let url = URL(string: "https://7tv.io/v3/users/twitch/\(broadcasterId)")!
        let response: SevenTVUserResponse = try await request(url: url)
        return response.emoteSet?.emotes.compactMap { emote(from: $0) } ?? []
    }

    private func emote(from data: SevenTVEmote) -> Emote? {
        guard let host = data.data?.host else { return nil }
        guard let imageURLs = resolveImageURLs(host: host) else { return nil }
        let isAnimated = host.files.contains { $0.format.uppercased() == "GIF" || $0.name.lowercased().hasSuffix(".gif") }
        return Emote(
            providerId: data.id,
            code: data.name,
            imageURLs: imageURLs,
            isAnimated: isAnimated,
            provider: .sevenTV
        )
    }

    private func resolveImageURLs(host: SevenTVHost) -> EmoteImageURLs? {
        let baseURL = normalizedHostURL(host.url)
        let webpFiles = host.files.filter { $0.format.uppercased() == "WEBP" }
        let preferredFiles = webpFiles.isEmpty ? host.files : webpFiles
        let urlByScale: [String: URL] = Dictionary(
            uniqueKeysWithValues: preferredFiles.compactMap { file -> (String, URL)? in
                guard let url = URL(string: "\(baseURL)/\(file.name)") else { return nil }
                return (file.scale, url)
            }
        )

        guard let url1x = urlByScale["1x"] ?? urlByScale["1"] else { return nil }
        let url2x = urlByScale["2x"] ?? urlByScale["2"]
        let url3x = urlByScale["3x"] ?? urlByScale["3"]
        let url4x = urlByScale["4x"] ?? urlByScale["4"]
        let fallback = webpFiles.isEmpty ? nil : fallbackURL(host: host)

        return EmoteImageURLs(
            url1x: url1x,
            url2x: url2x,
            url3x: url3x,
            url4x: url4x,
            preferred: url2x ?? url1x,
            fallback: fallback
        )
    }

    private func fallbackURL(host: SevenTVHost) -> URL? {
        let baseURL = normalizedHostURL(host.url)
        let fallbackFiles = host.files.filter { $0.format.uppercased() != "WEBP" }
        guard let file = fallbackFiles.first else { return nil }
        return URL(string: "\(baseURL)/\(file.name)")
    }

    private func normalizedHostURL(_ value: String) -> String {
        if value.hasPrefix("//") {
            return "https:\(value)"
        }
        if value.hasPrefix("http") {
            return value
        }
        return "https://\(value)"
    }

    private func request<T: Decodable>(url: URL) async throws -> T {
        let (data, response) = try await urlSession.data(from: url)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw SevenTVEmoteProviderError.httpError(statusCode: http.statusCode, payload: data)
        }
    }
}

public enum SevenTVEmoteProviderError: Error {
    case httpError(statusCode: Int, payload: Data)
}

private struct SevenTVEmoteSetResponse: Decodable {
    let emotes: [SevenTVEmote]
}

private struct SevenTVUserResponse: Decodable {
    let emoteSet: SevenTVEmoteSet?

    private enum CodingKeys: String, CodingKey {
        case emoteSet = "emote_set"
    }
}

private struct SevenTVEmoteSet: Decodable {
    let emotes: [SevenTVEmote]
}

private struct SevenTVEmote: Decodable {
    let id: String
    let name: String
    let data: SevenTVEmoteData?
}

private struct SevenTVEmoteData: Decodable {
    let host: SevenTVHost
}

private struct SevenTVHost: Decodable {
    let url: String
    let files: [SevenTVHostFile]
}

private struct SevenTVHostFile: Decodable {
    let name: String
    let format: String
    let scale: String
}
