import Combine
import Foundation

public enum ChatThemePreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

/// User-visible chat and appearance settings, persisted in UserDefaults.
public final class ChatSettings: ObservableObject, @unchecked Sendable {
    @Published public var showTimestamps: Bool { didSet { save() } }
    @Published public var showUsernames: Bool { didSet { save() } }
    @Published public var scrollbackLimit: Int { didSet { save() } }
    @Published public var allowAnimatedEmotes: Bool { didSet { save() } }
    @Published public var fontSize: Int { didSet { save() } }
    @Published public var lineSeparator: Bool { didSet { save() } }
    @Published public var checkeredMessages: Bool { didSet { save() } }
    @Published public var keepScreenOn: Bool { didSet { save() } }
    @Published public var showInput: Bool { didSet { save() } }
    @Published public var autoDisableInput: Bool { didSet { save() } }
    @Published public var showChips: Bool { didSet { save() } }
    @Published public var showChangelogs: Bool { didSet { save() } }
    @Published public var theme: ChatThemePreference { didSet { save() } }
    @Published public var trueDarkTheme: Bool { didSet { save() } }

    private let defaults: UserDefaults
    private let storageKey = "chat.settings.v2"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let snapshot = Self.load(from: defaults)
        showTimestamps = snapshot.showTimestamps
        showUsernames = snapshot.showUsernames
        scrollbackLimit = snapshot.scrollbackLimit
        allowAnimatedEmotes = snapshot.allowAnimatedEmotes
        fontSize = snapshot.fontSize
        lineSeparator = snapshot.lineSeparator
        checkeredMessages = snapshot.checkeredMessages
        keepScreenOn = snapshot.keepScreenOn
        showInput = snapshot.showInput
        autoDisableInput = snapshot.autoDisableInput
        showChips = snapshot.showChips
        showChangelogs = snapshot.showChangelogs
        theme = snapshot.theme
        trueDarkTheme = snapshot.trueDarkTheme
    }

    private func save() {
        let snapshot = Snapshot(
            showTimestamps: showTimestamps,
            showUsernames: showUsernames,
            scrollbackLimit: scrollbackLimit,
            allowAnimatedEmotes: allowAnimatedEmotes,
            fontSize: fontSize,
            lineSeparator: lineSeparator,
            checkeredMessages: checkeredMessages,
            keepScreenOn: keepScreenOn,
            showInput: showInput,
            autoDisableInput: autoDisableInput,
            showChips: showChips,
            showChangelogs: showChangelogs,
            theme: theme,
            trueDarkTheme: trueDarkTheme
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func load(from defaults: UserDefaults) -> Snapshot {
        guard let data = defaults.data(forKey: "chat.settings.v2"),
              let decoded = try? JSONDecoder().decode(Snapshot.self, from: data)
        else {
            return Snapshot()
        }
        return decoded
    }

    private struct Snapshot: Codable {
        var showTimestamps = true
        var showUsernames = true
        var scrollbackLimit = 500
        var allowAnimatedEmotes = true
        var fontSize = 14
        var lineSeparator = false
        var checkeredMessages = false
        var keepScreenOn = true
        var showInput = true
        var autoDisableInput = true
        var showChips = true
        var showChangelogs = true
        var theme = ChatThemePreference.system
        var trueDarkTheme = false
    }
}
