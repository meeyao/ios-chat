import SwiftUI
import DankChatCore

/// Displays the parent message context for a reply message.
///
/// Shows the original (parent) message that was replied to, followed by the
/// reply message itself. Presented as a sheet from `ChatMessageRow` when
/// reply metadata is available.
struct ReplyThreadView: View {
    let message: ChatMessage
    @ObservedObject var settings: ChatSettings
    @Environment(\.dismiss) private var dismiss

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let reply = message.replyMetadata {
                        parentSection(reply: reply)
                    }

                    Divider()

                    replySection
                }
                .padding()
            }
            .navigationTitle("Reply Thread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func parentSection(reply: ReplyMetadata) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Replying to")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(reply.parentDisplayName ?? reply.parentUserLogin ?? "Unknown")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()
            }

            Text(reply.parentMessageBody ?? "(message not available)")
                .font(.body)
                .foregroundStyle(reply.parentMessageBody != nil ? .primary : .secondary)
        }
        .padding()
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var replySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reply")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if settings.showTimestamps {
                    Text(Self.timestampFormatter.string(from: message.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(message.user.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(usernameColor ?? .primary)

                Spacer()
            }

            Text(message.text)
                .font(.body)
        }
        .padding()
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var usernameColor: Color? {
        UsernameColor.color(from: message.user.color)
    }
}
