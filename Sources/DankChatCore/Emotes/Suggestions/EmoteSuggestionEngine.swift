import Foundation

public struct EmoteSuggestionEngine {
    public init() {}

    public func suggestions(for text: String, cursor: Int, emotes: [Emote], limit: Int) -> [Emote] {
        guard let token = EmoteTokenization.currentToken(in: text, cursor: cursor) else {
            return []
        }
        return suggestions(for: token, emotes: emotes, limit: limit)
    }

    public func suggestions(for token: EmoteToken, emotes: [Emote], limit: Int) -> [Emote] {
        guard limit > 0 else { return [] }

        let query = token.isColonPrefixed ? token.query : token.text
        if query.isEmpty && !token.isColonPrefixed {
            return []
        }

        let candidates = uniqueEmotes(from: emotes)
            .compactMap { emote -> (Emote, Int)? in
                if query.isEmpty {
                    return (emote, -emote.code.count)
                }
                guard let score = score(code: emote.code, query: query) else { return nil }
                return (emote, score)
            }

        let sorted = candidates.sorted { lhs, rhs in
            if lhs.1 != rhs.1 {
                return lhs.1 > rhs.1
            }
            return lhs.0.code.localizedCaseInsensitiveCompare(rhs.0.code) == .orderedAscending
        }

        return sorted.prefix(limit).map { $0.0 }
    }

    private func uniqueEmotes(from emotes: [Emote]) -> [Emote] {
        var seen: Set<String> = []
        var unique: [Emote] = []
        for emote in emotes {
            guard !seen.contains(emote.code) else { continue }
            seen.insert(emote.code)
            unique.append(emote)
        }
        return unique
    }

    private func score(code: String, query: String) -> Int? {
        let lowerCode = code.lowercased()
        let lowerQuery = query.lowercased()

        if lowerCode.hasPrefix(lowerQuery) {
            return 1000 - lowerCode.count
        }

        guard let fuzzyScore = fuzzyScore(code: lowerCode, query: lowerQuery) else {
            return nil
        }

        return 600 - fuzzyScore - lowerCode.count
    }

    private func fuzzyScore(code: String, query: String) -> Int? {
        var index = code.startIndex
        var totalGap = 0

        for character in query {
            guard let matchIndex = code[index...].firstIndex(of: character) else {
                return nil
            }
            totalGap += code.distance(from: index, to: matchIndex)
            index = code.index(after: matchIndex)
        }

        return totalGap
    }
}
