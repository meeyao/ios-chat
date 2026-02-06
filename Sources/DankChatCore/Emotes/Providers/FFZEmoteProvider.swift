import Foundation

public final class FFZEmoteProvider {
    private let urlSession: URLSession

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    public func fetchGlobalEmotes() async throws -> [Emote] {
        let url = URL(string: "https://api.frankerfacez.com/v1/set/global")!
        let response: FFZSetResponse = try await request(url: url)
        return response.sets.values.flatMap { $0.emoticons }.compactMap { emote(from: $0) }
    }

    public func fetchChannelEmotes(channelLogin: String) async throws -> [Emote] {
        let normalized = channelLogin.lowercased()
        let url = URL(string: "https://api.frankerfacez.com/v1/room/\(normalized)")!
        let response: FFZSetResponse = try await request(url: url)
        return response.sets.values.flatMap { $0.emoticons }.compactMap { emote(from: $0) }
    }

    private func emote(from data: FFZEmote) -> Emote? {
        let isAnimated = data.animated != nil
        let urlMap = (data.animated ?? data.urls)
        guard let url1xString = urlMap["1"], let url1x = normalizedURL(url1xString) else {
            return nil
        }
        let url2x = urlMap["2"].flatMap(normalizedURL)
        let url3x = urlMap["4"].flatMap(normalizedURL)
        let imageURLs = EmoteImageURLs(url1x: url1x, url2x: url2x, url3x: url3x, preferred: url2x ?? url1x)

        return Emote(
            providerId: String(data.id),
            code: data.name,
            imageURLs: imageURLs,
            isAnimated: isAnimated,
            provider: .ffz
        )
    }

    private func normalizedURL(_ value: String) -> URL? {
        if value.hasPrefix("//") {
            return URL(string: "https:\(value)")
        }
        return URL(string: value)
    }

    private func request<T: Decodable>(url: URL) async throws -> T {
        let (data, response) = try await urlSession.data(from: url)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw FFZEmoteProviderError.httpError(statusCode: http.statusCode, payload: data)
        }
    }
}

public enum FFZEmoteProviderError: Error {
    case httpError(statusCode: Int, payload: Data)
}

private struct FFZSetResponse: Decodable {
    let sets: [String: FFZSet]
}

private struct FFZSet: Decodable {
    let emoticons: [FFZEmote]
}

private struct FFZEmote: Decodable {
    let id: Int
    let name: String
    let urls: [String: String]
    let animated: [String: String]?
}
