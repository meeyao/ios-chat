import Foundation

public struct CommandSuggestion: Identifiable, Equatable, Sendable {
    public let id: String
    public let command: String
    public let description: String?
    public let insertion: String

    public init(command: String, description: String? = nil, insertion: String? = nil) {
        self.command = command
        self.description = description
        self.insertion = insertion ?? command + " "
        self.id = command
    }
}

public actor CommandSuggestionsClient {
    public enum CommandSuggestionsError: Error {
        case invalidURL
        case httpError(statusCode: Int, payload: Data)
    }

    private let baseURL: URL
    private let urlSession: URLSession
    private let cacheTTL: TimeInterval = 300

    private var commandsCache: CacheEntry<[CommandDefinition]>?
    private var channelsCache: CacheEntry<[ChannelDefinition]>?
    private var aliasCache: [String: CacheEntry<[AliasDefinition]>] = [:]

    public init(
        baseURL: URL = URL(string: "https://supinic.com/api/")!,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    public func suggestions(for input: String, user: String?) async throws -> [CommandSuggestion] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return [] }

        let afterSlash = String(trimmed.dropFirst())
        let parts = afterSlash.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        let commandToken = parts.first.map(String.init) ?? ""
        let argument = parts.count > 1 ? String(parts[1]) : ""

        let argumentPrefix = argument.trimmingCharacters(in: .whitespacesAndNewlines)
        if !argumentPrefix.isEmpty {
            if isChannelCommand(commandToken) {
                let channels = try await fetchChannels()
                return channels
                    .filter { isChannelActive($0) }
                    .filter { $0.name.lowercased().hasPrefix(argumentPrefix.lowercased()) }
                    .prefix(20)
                    .map { channel in
                        CommandSuggestion(
                            command: channel.name,
                            description: "Channel",
                            insertion: "/\(commandToken) \(channel.name) "
                        )
                    }
            }

            if isAliasCommand(commandToken), let user {
                let aliases = try await fetchAliases(for: user)
                return aliases
                    .filter { $0.name.lowercased().hasPrefix(argumentPrefix.lowercased()) }
                    .prefix(20)
                    .map { alias in
                        CommandSuggestion(
                            command: alias.name,
                            description: "Alias",
                            insertion: "/\(commandToken) \(alias.name) "
                        )
                    }
            }
        }

        let commands = try await fetchCommands()
        let prefix = commandToken.lowercased()
        var seen: Set<String> = []
        var suggestions: [CommandSuggestion] = []

        for command in commands {
            if prefix.isEmpty || command.name.lowercased().hasPrefix(prefix) {
                let insertion = "/\(command.name) "
                if seen.insert(insertion).inserted {
                    suggestions.append(
                        CommandSuggestion(
                            command: insertion.trimmingCharacters(in: .whitespaces),
                            description: "Command",
                            insertion: insertion
                        )
                    )
                }
            }

            for alias in command.aliases {
                guard alias.lowercased().hasPrefix(prefix) else { continue }
                let insertion = "/\(alias) "
                if seen.insert(insertion).inserted {
                    suggestions.append(
                        CommandSuggestion(
                            command: insertion.trimmingCharacters(in: .whitespaces),
                            description: "Alias for /\(command.name)",
                            insertion: insertion
                        )
                    )
                }
            }
        }

        return Array(suggestions.prefix(20))
    }

    private func isChannelCommand(_ token: String) -> Bool {
        let lowered = token.lowercased()
        return lowered == "join" || lowered == "j" || lowered == "channel"
    }

    private func isAliasCommand(_ token: String) -> Bool {
        let lowered = token.lowercased()
        return lowered == "alias" || lowered == "aliases"
    }

    private func fetchCommands() async throws -> [CommandDefinition] {
        if let cached = commandsCache, cached.isFresh(ttl: cacheTTL) {
            return cached.value
        }
        let response: CommandListResponse = try await request(path: "bot/command/list/")
        commandsCache = CacheEntry(value: response.data, timestamp: Date())
        return response.data
    }

    private func fetchChannels() async throws -> [ChannelDefinition] {
        if let cached = channelsCache, cached.isFresh(ttl: cacheTTL) {
            return cached.value
        }
        let response: ChannelListResponse = try await request(
            path: "bot/channel/list",
            queryItems: [URLQueryItem(name: "platformName", value: "twitch")]
        )
        channelsCache = CacheEntry(value: response.data, timestamp: Date())
        return response.data
    }

    private func fetchAliases(for user: String) async throws -> [AliasDefinition] {
        if let cached = aliasCache[user], cached.isFresh(ttl: cacheTTL) {
            return cached.value
        }
        let safeUser = user.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? user
        let response: AliasListResponse = try await request(path: "bot/user/\(safeUser)/alias/list/")
        aliasCache[user] = CacheEntry(value: response.data, timestamp: Date())
        return response.data
    }

    private func isChannelActive(_ channel: ChannelDefinition) -> Bool {
        let mode = channel.mode.lowercased()
        return mode != "last seen" && mode != "read"
    }

    private func request<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw CommandSuggestionsError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let requestURL = components.url else {
            throw CommandSuggestionsError.invalidURL
        }

        let (data, response) = try await urlSession.data(from: requestURL)
        guard let http = response as? HTTPURLResponse else {
            return try JSONDecoder().decode(T.self, from: data)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CommandSuggestionsError.httpError(statusCode: http.statusCode, payload: data)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct CacheEntry<Value> {
    let value: Value
    let timestamp: Date

    func isFresh(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) < ttl
    }
}

private struct CommandListResponse: Decodable {
    let data: [CommandDefinition]
}

private struct CommandDefinition: Decodable {
    let name: String
    let aliases: [String]
}

private struct ChannelListResponse: Decodable {
    let data: [ChannelDefinition]
}

private struct ChannelDefinition: Decodable {
    let name: String
    let mode: String
}

private struct AliasListResponse: Decodable {
    let data: [AliasDefinition]
}

private struct AliasDefinition: Decodable {
    let name: String
}
