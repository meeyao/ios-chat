import Combine
import Foundation

/// A persisted custom command with a trigger name and a template body.
///
/// Templates support placeholders: `{channel}` and `{user}` which are expanded
/// at send time by ``CommandResolver``.
public struct CustomCommand: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    /// The trigger name without the leading `/`. For example `"hello"` matches `/hello`.
    public var name: String
    /// The template body to expand. May contain `{channel}` and `{user}` placeholders.
    public var template: String

    public init(id: UUID = UUID(), name: String, template: String) {
        self.id = id
        self.name = name
        self.template = template
    }
}

/// Observable store that persists custom commands in `UserDefaults`.
///
/// Commands are keyed under `"dankchat_custom_commands"` and serialised as JSON.
@MainActor
public final class CommandStore: ObservableObject {
    @Published public private(set) var commands: [CustomCommand] = []

    private let key = "dankchat_custom_commands"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: - CRUD

    public func add(_ command: CustomCommand) {
        commands.append(command)
        save()
    }

    public func update(_ command: CustomCommand) {
        guard let index = commands.firstIndex(where: { $0.id == command.id }) else { return }
        commands[index] = command
        save()
    }

    public func delete(at offsets: IndexSet) {
        commands.remove(atOffsets: offsets)
        save()
    }

    public func delete(id: UUID) {
        commands.removeAll(where: { $0.id == id })
        save()
    }

    // MARK: - Lookup

    /// Returns the command matching the given trigger name (case-insensitive), if any.
    public func command(named name: String) -> CustomCommand? {
        let lowered = name.lowercased()
        return commands.first(where: { $0.name.lowercased() == lowered })
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: key) else { return }
        do {
            commands = try JSONDecoder().decode([CustomCommand].self, from: data)
        } catch {
            commands = []
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(commands) else { return }
        defaults.set(data, forKey: key)
    }
}
