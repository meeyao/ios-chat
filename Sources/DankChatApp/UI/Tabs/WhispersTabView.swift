import SwiftUI
import DankChatCore

/// Displays whisper conversations in a list with a drill-down message thread.
struct WhispersTabView: View {
    @EnvironmentObject private var whisperStore: WhisperStore

    var body: some View {
        Group {
            if whisperStore.conversations.isEmpty {
                emptyState
            } else {
                conversationList
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No whispers yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Whisper conversations will appear here.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Conversation List

    private var conversationList: some View {
        List {
            ForEach(whisperStore.conversations) { conversation in
                NavigationLink {
                    WhisperThreadView(conversation: conversation)
                        .environmentObject(whisperStore)
                } label: {
                    ConversationRow(conversation: conversation)
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Conversation Row

private struct ConversationRow: View {
    let conversation: WhisperConversation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(conversation.userName)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if let last = conversation.messages.last {
                    Text(last.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let lastMessage = conversation.messages.last {
                HStack(spacing: 4) {
                    if lastMessage.isOutgoing {
                        Text("You:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(lastMessage.text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Whisper Thread View

/// Shows the message thread for a single whisper conversation with a compose field.
struct WhisperThreadView: View {
    let conversation: WhisperConversation
    @EnvironmentObject private var whisperStore: WhisperStore
    @State private var draft: String = ""

    /// Resolve the live conversation from the store (may be updated).
    private var liveConversation: WhisperConversation? {
        whisperStore.conversations.first(where: { $0.id == conversation.id })
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList

            Divider()

            composeBar
        }
        .navigationTitle(conversation.userName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(liveConversation?.messages ?? conversation.messages) { message in
                        WhisperBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: liveConversation?.messages.count) { _ in
                if let lastId = liveConversation?.messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Compose Bar

    private var composeBar: some View {
        HStack(spacing: 8) {
            TextField("Send a whisper...", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .onSubmit { sendMessage() }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func sendMessage() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""

        Task {
            await whisperStore.sendWhisper(
                toUserId: conversation.id,
                toUserLogin: conversation.userLogin,
                toUserName: conversation.userName,
                text: text
            )
        }
    }
}

// MARK: - Whisper Bubble

private struct WhisperBubble: View {
    let message: WhisperMessage

    var body: some View {
        HStack {
            if message.isOutgoing { Spacer(minLength: 40) }

            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 2) {
                if !message.isOutgoing {
                    Text(message.fromUserName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(message.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(message.isOutgoing ? Color.accentColor.opacity(0.2) : Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 4) {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if message.isOutgoing {
                        deliveryIndicator
                    }
                }
            }

            if !message.isOutgoing { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var deliveryIndicator: some View {
        switch message.deliveryState {
        case .sent:
            Text("Sent (delivery not guaranteed)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .failed:
            Text("Failed to send")
                .font(.caption2)
                .foregroundStyle(.red)
        case .received:
            EmptyView()
        }
    }
}
