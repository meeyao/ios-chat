import Foundation

public final class BTTVEmoteProvider {
    private let urlSession: URLSession

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    public func fetchGlobalEmotes() async throws -> [Emote] {
        let url = URL(string: "https://api.betterttv.net/3/cached/emotes/global")!
        let emotes: [BTTVEmote] = try await request(url: url)
        return emotes.map { emote(from: $0) }
    }

    public func fetchChannelEmotes(broadcasterId: String) async throws -> [Emote] {
        let url = URL(string: "https://api.betterttv.net/3/cached/users/twitch/\(broadcasterId)")!
        let response: BTTVChannelResponse = try await request(url: url)
        let combined = response.channelEmotes + response.sharedEmotes
        return combined.map { emote(from: $0) }
    }

    private func emote(from data: BTTVEmote) -> Emote {
        let base = "https://cdn.betterttv.net/emote/\(data.id)"
        let url1x = URL(string: "\(base)/1x")!
        let url2x = URL(string: "\(base)/2x")
        let url3x = URL(string: "\(base)/3x")

        let webp1x = URL(string: "\(base)/1x.webp")
        let webp2x = URL(string: "\(base)/2x.webp")
        let webp3x = URL(string: "\(base)/3x.webp")
        let prefersWebP = data.imageType.lowercased() != "gif"
        let preferred = prefersWebP ? (webp2x ?? webp1x ?? url1x) : (url2x ?? url1x)

        let imageURLs = EmoteImageURLs(
            url1x: url1x,
            url2x: prefersWebP ? webp2x ?? url2x : url2x,
            url3x: prefersWebP ? webp3x ?? url3x : url3x,
            preferred: preferred,
            fallback: prefersWebP ? (url2x ?? url1x) : nil
        )

        return Emote(
            providerId: data.id,
            code: data.code,
            imageURLs: imageURLs,
            isAnimated: data.imageType.lowercased() == "gif",
            provider: .bttv
        )
    }

    private func request<T: Decodable>(url: URL) async throws -> T {
        let (data, response) = try await urlSession.data(from: url)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw BTTVEmoteProviderError.httpError(statusCode: http.statusCode, payload: data)
        }
    }
}

public enum BTTVEmoteProviderError: Error {
    case httpError(statusCode: Int, payload: Data)
}

private struct BTTVChannelResponse: Decodable {
    let channelEmotes: [BTTVEmote]
    let sharedEmotes: [BTTVEmote]
}

private struct BTTVEmote: Decodable {
    let id: String
    let code: String
    let imageType: String
}
