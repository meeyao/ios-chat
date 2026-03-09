import Foundation

public struct ChatUser: Equatable, Sendable {
    public let id: String?
    public let displayName: String
    public let login: String
    public let color: String?

    public init(id: String? = nil, displayName: String, login: String, color: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.login = login
        self.color = color
    }
}
