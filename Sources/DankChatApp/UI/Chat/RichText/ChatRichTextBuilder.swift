import UIKit
import DankChatCore

struct ChatRichTextBuilder {
    struct Configuration {
        let font: UIFont
        let textColor: UIColor
        let allowAnimatedEmotes: Bool
        let emoteScale: CGFloat

        init(
            font: UIFont,
            textColor: UIColor = .label,
            allowAnimatedEmotes: Bool,
            emoteScale: CGFloat = 1.3
        ) {
            self.font = font
            self.textColor = textColor
            self.allowAnimatedEmotes = allowAnimatedEmotes
            self.emoteScale = emoteScale
        }
    }

    private enum Segment {
        case text(String)
        case emote(Emote)

        var isEmote: Bool {
            if case .emote = self { return true }
            return false
        }
    }

    private static let tokenRegex = try? NSRegularExpression(pattern: "\\s+|\\S+")
    private static let wrapSpacer = "\u{200B}"

    private let emoteStore: EmoteStore

    init(emoteStore: EmoteStore) {
        self.emoteStore = emoteStore
    }

    func build(message: ChatMessage, configuration: Configuration) -> NSAttributedString {
        let segments = segments(for: message)
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: configuration.font,
            .foregroundColor: configuration.textColor
        ]

        let result = NSMutableAttributedString()

        for index in segments.indices {
            let segment = segments[index]
            let previousIsEmote = index > 0 && segments[index - 1].isEmote
            let nextIsEmote = index + 1 < segments.count && segments[index + 1].isEmote

            switch segment {
            case .text(let text):
                if text == " " && previousIsEmote && nextIsEmote {
                    result.append(NSAttributedString(string: Self.wrapSpacer, attributes: baseAttributes))
                    continue
                }
                result.append(NSAttributedString(string: text, attributes: baseAttributes))
            case .emote(let emote):
                if previousIsEmote {
                    result.append(NSAttributedString(string: Self.wrapSpacer, attributes: baseAttributes))
                }
                let imageURL = emoteStore.preferredImageURL(for: emote, allowAnimated: configuration.allowAnimatedEmotes)
                let attachment = ChatEmoteAttachment(
                    emote: emote,
                    imageURL: imageURL,
                    isAnimated: configuration.allowAnimatedEmotes && emote.isAnimated,
                    font: configuration.font,
                    scale: configuration.emoteScale
                )
                let attributedAttachment = NSAttributedString(attachment: attachment)
                result.append(attributedAttachment)
            }
        }

        result.addAttribute(.font, value: configuration.font, range: NSRange(location: 0, length: result.length))
        return result
    }

    private func segments(for message: ChatMessage) -> [Segment] {
        let channelLogin = message.channel
        let nsText = message.text as NSString
        let occurrences = message.twitchEmotes.sorted { $0.range.location < $1.range.location }
        var segments: [Segment] = []
        var cursor = 0

        for occurrence in occurrences {
            guard occurrence.range.location >= cursor else { continue }
            let prefixLength = occurrence.range.location - cursor
            if prefixLength > 0 {
                let prefix = nsText.substring(with: NSRange(location: cursor, length: prefixLength))
                appendTextSegments(prefix, channelLogin: channelLogin, segments: &segments)
            }

            if let emote = emoteStore.resolveTwitchEmote(occurrence: occurrence, channelLogin: channelLogin) {
                segments.append(.emote(emote))
            } else {
                let fallback = nsText.substring(with: occurrence.range)
                appendTextSegments(fallback, channelLogin: channelLogin, segments: &segments)
            }

            cursor = occurrence.range.location + occurrence.range.length
        }

        if cursor < nsText.length {
            let suffix = nsText.substring(from: cursor)
            appendTextSegments(suffix, channelLogin: channelLogin, segments: &segments)
        }

        return segments
    }

    private func appendTextSegments(_ text: String, channelLogin: String, segments: inout [Segment]) {
        guard let regex = Self.tokenRegex else {
            segments.append(.text(text))
            return
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            let token = nsText.substring(with: match.range)
            if token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(.text(token))
            } else if let emote = emoteStore.resolveEmote(code: token, channelLogin: channelLogin) {
                segments.append(.emote(emote))
            } else {
                segments.append(.text(token))
            }
        }
    }
}

final class ChatEmoteAttachment: NSTextAttachment {
    let emote: Emote
    let imageURL: URL
    let isAnimated: Bool

    init(emote: Emote, imageURL: URL, isAnimated: Bool, font: UIFont, scale: CGFloat) {
        self.emote = emote
        self.imageURL = imageURL
        self.isAnimated = isAnimated
        super.init(data: nil, ofType: nil)

        let emoteSize = ceil(font.lineHeight * scale)
        let yOffset = font.descender
        bounds = CGRect(x: 0, y: yOffset, width: emoteSize, height: emoteSize)
    }

    required init?(coder: NSCoder) {
        nil
    }
}
