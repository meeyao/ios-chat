import Foundation

public struct IRCMessage: Equatable {
    public let tags: [String: String?]
    public let prefix: String?
    public let command: String
    public let params: [String]

    public init(tags: [String: String?] = [:], prefix: String? = nil, command: String, params: [String] = []) {
        self.tags = tags
        self.prefix = prefix
        self.command = command
        self.params = params
    }
}
