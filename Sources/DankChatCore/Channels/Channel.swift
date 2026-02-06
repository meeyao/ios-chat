import Foundation

public struct Channel: Identifiable, Equatable {
    public let id: String
    public var displayName: String
    public var isPinned: Bool
    public var sortOrder: Int

    public init(id: String, displayName: String, isPinned: Bool, sortOrder: Int) {
        self.id = id
        self.displayName = displayName
        self.isPinned = isPinned
        self.sortOrder = sortOrder
    }

    public static func normalizeId(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.hasPrefix("#") {
            return String(trimmed.dropFirst()).lowercased()
        }
        return trimmed.lowercased()
    }

    public static func displayName(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else { return trimmed }
        return String(trimmed.dropFirst())
    }
}
