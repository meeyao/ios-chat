import Foundation

public enum ProviderID: String, CaseIterable, Sendable {
    case twitch
    case sevenTV
    case bttv
    case ffz

    public var displayName: String {
        switch self {
        case .twitch:
            return "Twitch"
        case .sevenTV:
            return "7TV"
        case .bttv:
            return "BTTV"
        case .ffz:
            return "FFZ"
        }
    }
}

public struct EmoteImageURLs: Equatable, Sendable {
    public let url1x: URL
    public let url2x: URL?
    public let url3x: URL?
    public let url4x: URL?
    public let preferred: URL
    public let fallback: URL?

    public init(
        url1x: URL,
        url2x: URL? = nil,
        url3x: URL? = nil,
        url4x: URL? = nil,
        preferred: URL? = nil,
        fallback: URL? = nil
    ) {
        self.url1x = url1x
        self.url2x = url2x
        self.url3x = url3x
        self.url4x = url4x
        self.preferred = preferred ?? url2x ?? url1x
        self.fallback = fallback
    }
}

public struct Emote: Identifiable, Equatable, Sendable {
    public let id: String
    public let providerId: String
    public let code: String
    public let imageURLs: EmoteImageURLs
    public let isAnimated: Bool
    public let provider: ProviderID

    public init(
        providerId: String,
        code: String,
        imageURLs: EmoteImageURLs,
        isAnimated: Bool,
        provider: ProviderID
    ) {
        self.providerId = providerId
        self.code = code
        self.imageURLs = imageURLs
        self.isAnimated = isAnimated
        self.provider = provider
        self.id = "\(provider.rawValue):\(providerId)"
    }
}
