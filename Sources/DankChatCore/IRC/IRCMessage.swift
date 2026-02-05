import Foundation

struct IRCMessage: Equatable {
    let tags: [String: String?]
    let prefix: String?
    let command: String
    let params: [String]

    init(tags: [String: String?] = [:], prefix: String? = nil, command: String, params: [String] = []) {
        self.tags = tags
        self.prefix = prefix
        self.command = command
        self.params = params
    }
}
