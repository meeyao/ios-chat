import Combine
import Foundation
import UserNotifications

/// Controls how a username is inserted when mentioning a user.
public enum MentionFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case name
    case nameComma
    case atName
    case atNameComma

    public var id: String { rawValue }

    public var template: String {
        switch self {
        case .name: return "name"
        case .nameComma: return "name,"
        case .atName: return "@name"
        case .atNameComma: return "@name,"
        }
    }

    public func mention(for user: String) -> String {
        template.replacingOccurrences(of: "name", with: user) + " "
    }
}

public struct ChatNotificationSettings: Codable, Equatable, Sendable {
    public var showNotifications: Bool
    public var showWhisperNotifications: Bool
    public var mentionFormat: MentionFormat

    public init(
        showNotifications: Bool = true,
        showWhisperNotifications: Bool = true,
        mentionFormat: MentionFormat = .name
    ) {
        self.showNotifications = showNotifications
        self.showWhisperNotifications = showWhisperNotifications
        self.mentionFormat = mentionFormat
    }
}

/// Posts local notifications for mentions, highlights, and whispers.
///
/// iOS does not allow a persistent IRC socket in the background, so these
/// notifications fire while the app is running and present as banners in the
/// foreground via the notification-center delegate.
@MainActor
public final class ChatNotificationService: NSObject, ObservableObject {
    @Published public var settings: ChatNotificationSettings {
        didSet { save() }
    }
    @Published public private(set) var isAuthorized = false

    private let defaults: UserDefaults
    private let storageKey = "notifications.settings.v1"
    private let center = UNUserNotificationCenter.current()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(ChatNotificationSettings.self, from: data) {
            settings = decoded
        } else {
            settings = ChatNotificationSettings()
        }
        super.init()
        center.delegate = self
        Task { await refreshAuthorization() }
    }

    public func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            isAuthorized = granted
            if !granted {
                await refreshAuthorization()
            }
        } catch {
            isAuthorized = false
        }
    }

    public func refreshAuthorization() async {
        let current = await center.notificationSettings()
        switch current.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }

    public func notifyMention(message: ChatMessage, channel: String) {
        guard settings.showNotifications else { return }
        deliver(
            title: "\(message.user.displayName) mentioned you in #\(channel)",
            body: message.text,
            identifier: message.id ?? UUID().uuidString,
            channel: channel
        )
    }

    public func notifyHighlight(message: ChatMessage, channel: String) {
        guard settings.showNotifications else { return }
        deliver(
            title: "Highlight in #\(channel)",
            body: "\(message.user.displayName): \(message.text)",
            identifier: "highlight-\(message.id ?? UUID().uuidString)",
            channel: channel
        )
    }

    public func notifyWhisper(_ message: WhisperMessage) {
        guard settings.showNotifications, settings.showWhisperNotifications else { return }
        deliver(
            title: "Whisper from \(message.fromUserName)",
            body: message.text,
            identifier: "whisper-\(message.id)",
            channel: nil
        )
    }

    private func deliver(title: String, body: String, identifier: String, channel: String?) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let channel {
            content.userInfo = ["channel": channel]
        }
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        Task { try? await center.add(request) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

extension ChatNotificationService: UNUserNotificationCenterDelegate {
    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
