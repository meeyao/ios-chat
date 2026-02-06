import Foundation

public struct EmoteToken: Equatable, Sendable {
    public let range: NSRange
    public let text: String
    public let isColonPrefixed: Bool
    public let query: String

    public init(range: NSRange, text: String, isColonPrefixed: Bool, query: String) {
        self.range = range
        self.text = text
        self.isColonPrefixed = isColonPrefixed
        self.query = query
    }
}

public enum EmoteTokenization {
    public static func currentToken(in text: String, cursor: Int) -> EmoteToken? {
        let nsText = text as NSString
        let safeCursor = max(0, min(cursor, nsText.length))
        guard nsText.length > 0 else { return nil }

        let start = tokenStart(in: nsText, cursor: safeCursor)
        let end = tokenEnd(in: nsText, cursor: safeCursor)
        guard start < end else { return nil }

        let range = NSRange(location: start, length: end - start)
        let tokenText = nsText.substring(with: range)
        let isColonPrefixed = tokenText.hasPrefix(":")
        let query = isColonPrefixed ? String(tokenText.dropFirst()) : tokenText

        if query.isEmpty && !isColonPrefixed {
            return nil
        }

        return EmoteToken(range: range, text: tokenText, isColonPrefixed: isColonPrefixed, query: query)
    }

    public static func replacingToken(
        in text: String,
        token: EmoteToken,
        with replacement: String,
        appendSpace: Bool = true
    ) -> (text: String, cursor: Int)? {
        let nsText = text as NSString
        guard NSMaxRange(token.range) <= nsText.length else { return nil }

        let insertion = appendSpace ? "\(replacement) " : replacement
        let updated = nsText.replacingCharacters(in: token.range, with: insertion)
        let newCursor = token.range.location + (insertion as NSString).length
        return (updated, newCursor)
    }

    private static func tokenStart(in text: NSString, cursor: Int) -> Int {
        var index = cursor
        while index > 0 {
            let candidate = text.character(at: index - 1)
            if isWhitespace(candidate) {
                break
            }
            index -= 1
        }
        return index
    }

    private static func tokenEnd(in text: NSString, cursor: Int) -> Int {
        var index = cursor
        while index < text.length {
            let candidate = text.character(at: index)
            if isWhitespace(candidate) {
                break
            }
            index += 1
        }
        return index
    }

    private static func isWhitespace(_ character: unichar) -> Bool {
        guard let scalar = UnicodeScalar(character) else { return false }
        return CharacterSet.whitespacesAndNewlines.contains(scalar)
    }
}
