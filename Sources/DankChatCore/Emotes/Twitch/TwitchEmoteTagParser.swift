import Foundation

public enum TwitchEmoteTagParser {
    public static func parse(_ tagValue: String?, in messageText: String) -> [TwitchEmoteOccurrence] {
        guard let tagValue, !tagValue.isEmpty else { return [] }

        let textLength = (messageText as NSString).length
        var occurrences: [TwitchEmoteOccurrence] = []

        for entry in tagValue.split(separator: "/") {
            let parts = entry.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let emoteId = String(parts[0])
            let rangesPart = parts[1]

            for rangeToken in rangesPart.split(separator: ",") {
                let bounds = rangeToken.split(separator: "-", maxSplits: 1)
                guard bounds.count == 2,
                      let start = Int(bounds[0]),
                      let end = Int(bounds[1]),
                      start >= 0,
                      end >= start
                else {
                    continue
                }

                let length = end - start + 1
                guard start + length <= textLength else { continue }

                occurrences.append(TwitchEmoteOccurrence(
                    emoteId: emoteId,
                    range: NSRange(location: start, length: length)
                ))
            }
        }

        return occurrences
    }
}
