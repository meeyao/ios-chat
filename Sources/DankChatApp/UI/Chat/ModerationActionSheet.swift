import SwiftUI
import DankChatCore

/// A sheet that presents moderation actions for a specific chat message.
///
/// Actions include timeout (with duration presets), ban, unban, and delete message.
/// Each action calls the corresponding Helix service and appends a system message
/// to the channel timeline as feedback.
struct ModerationActionSheet: View {
    let message: ChatMessage
    let channelId: String
    let moderatorId: String
    let moderationService: HelixModerationService
    let chatMessagesService: HelixChatMessagesService
    let channelStore: ChannelStore

    @Environment(\.dismiss) private var dismiss
    @State private var isPerformingAction = false
    @State private var showTimeoutPicker = false

    var body: some View {
        NavigationStack {
            List {
                if let targetName = targetDisplayName {
                    Section {
                        Label("Actions for \(targetName)", systemImage: "shield.lefthalf.filled")
                            .font(.headline)
                    }
                }

                Section("Timeout") {
                    Button {
                        showTimeoutPicker.toggle()
                    } label: {
                        Label("Timeout...", systemImage: "clock.badge.xmark")
                    }
                    .disabled(isPerformingAction)

                    if showTimeoutPicker {
                        ForEach(TimeoutDuration.allCases) { duration in
                            Button {
                                performTimeout(duration: duration)
                            } label: {
                                HStack {
                                    Text(duration.label)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .disabled(isPerformingAction)
                        }
                    }
                }

                Section("Ban") {
                    Button(role: .destructive) {
                        performBan()
                    } label: {
                        Label("Ban User", systemImage: "xmark.circle.fill")
                    }
                    .disabled(isPerformingAction)

                    Button {
                        performUnban()
                    } label: {
                        Label("Unban User", systemImage: "checkmark.circle")
                    }
                    .disabled(isPerformingAction)
                }

                if message.id != nil {
                    Section("Message") {
                        Button(role: .destructive) {
                            performDeleteMessage()
                        } label: {
                            Label("Delete Message", systemImage: "trash")
                        }
                        .disabled(isPerformingAction)
                    }
                }
            }
            .navigationTitle("Moderation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if isPerformingAction {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Performing action...")
                                .padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                }
            }
        }
    }

    // MARK: - Target Info

    private var targetDisplayName: String? {
        let name = message.user.displayName
        return name.isEmpty ? nil : name
    }

    private var targetUserId: String? {
        message.user.id
    }

    // MARK: - Actions

    private func performTimeout(duration: TimeoutDuration) {
        guard let userId = targetUserId else {
            appendFeedback(success: false, text: "Cannot timeout: unknown user ID")
            return
        }

        isPerformingAction = true
        Task {
            defer {
                Task { @MainActor in
                    isPerformingAction = false
                    dismiss()
                }
            }
            do {
                try await moderationService.timeoutUser(
                    broadcasterId: channelId,
                    moderatorId: moderatorId,
                    userId: userId,
                    durationSeconds: duration.rawValue
                )
                appendFeedback(
                    success: true,
                    text: "Timed out \(message.user.displayName) for \(duration.label)"
                )
            } catch {
                appendFeedback(
                    success: false,
                    text: "Failed to timeout \(message.user.displayName): \(errorDescription(error))"
                )
            }
        }
    }

    private func performBan() {
        guard let userId = targetUserId else {
            appendFeedback(success: false, text: "Cannot ban: unknown user ID")
            return
        }

        isPerformingAction = true
        Task {
            defer {
                Task { @MainActor in
                    isPerformingAction = false
                    dismiss()
                }
            }
            do {
                try await moderationService.banUser(
                    broadcasterId: channelId,
                    moderatorId: moderatorId,
                    userId: userId
                )
                appendFeedback(
                    success: true,
                    text: "Banned \(message.user.displayName)"
                )
            } catch {
                appendFeedback(
                    success: false,
                    text: "Failed to ban \(message.user.displayName): \(errorDescription(error))"
                )
            }
        }
    }

    private func performUnban() {
        guard let userId = targetUserId else {
            appendFeedback(success: false, text: "Cannot unban: unknown user ID")
            return
        }

        isPerformingAction = true
        Task {
            defer {
                Task { @MainActor in
                    isPerformingAction = false
                    dismiss()
                }
            }
            do {
                try await moderationService.unbanUser(
                    broadcasterId: channelId,
                    moderatorId: moderatorId,
                    userId: userId
                )
                appendFeedback(
                    success: true,
                    text: "Unbanned \(message.user.displayName)"
                )
            } catch {
                appendFeedback(
                    success: false,
                    text: "Failed to unban \(message.user.displayName): \(errorDescription(error))"
                )
            }
        }
    }

    private func performDeleteMessage() {
        guard let messageId = message.id else {
            appendFeedback(success: false, text: "Cannot delete: no message ID")
            return
        }

        isPerformingAction = true
        Task {
            defer {
                Task { @MainActor in
                    isPerformingAction = false
                    dismiss()
                }
            }
            do {
                try await chatMessagesService.deleteMessage(
                    broadcasterId: channelId,
                    moderatorId: moderatorId,
                    messageId: messageId
                )
                appendFeedback(
                    success: true,
                    text: "Deleted message from \(message.user.displayName)"
                )
            } catch {
                appendFeedback(
                    success: false,
                    text: "Failed to delete message: \(errorDescription(error))"
                )
            }
        }
    }

    // MARK: - Feedback

    private func appendFeedback(success: Bool, text: String) {
        let prefix = success ? "[Mod]" : "[Mod Error]"
        channelStore.appendSystemMessage(
            channelId: message.channel,
            text: "\(prefix) \(text)"
        )
    }

    private func errorDescription(_ error: Error) -> String {
        if let helixError = error as? HelixError {
            switch helixError {
            case .missingAccessToken:
                return "Not authenticated"
            case .httpError(let statusCode, _):
                switch statusCode {
                case 401: return "Unauthorized (missing scope or expired token)"
                case 403: return "Forbidden (not a moderator in this channel)"
                case 404: return "Not found (message may have been deleted)"
                case 409: return "Conflict (user may already be banned/unbanned)"
                case 422: return "Cannot ban/timeout this user"
                case 429: return "Rate limited, try again later"
                default: return "HTTP \(statusCode)"
                }
            case .invalidURL:
                return "Invalid request"
            case .decodingError(let message):
                return message
            }
        }
        return error.localizedDescription
    }
}
