import Foundation

public enum TwitchBadgeTagParser {
    public static func parse(_ tagValue: String?) -> [TwitchBadgeTag] {
        guard let tagValue, !tagValue.isEmpty else { return [] }

        return tagValue.split(separator: ",").compactMap { entry in
            let parts = entry.split(separator: "/", maxSplits: 1)
            guard parts.count == 2 else { return nil }

            let id = String(parts[0])
            let version = String(parts[1])
            guard !id.isEmpty, !version.isEmpty else { return nil }

            return TwitchBadgeTag(id: id, version: version)
        }
    }
}
