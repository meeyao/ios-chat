import SwiftUI
import DankChatCore

struct ChatTimelineView: View {
    @ObservedObject var store: ChatStore
    @ObservedObject var settings: ChatSettings

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(store.entries.indices, id: \.self) { index in
                        row(for: store.entries[index])
                            .id(index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onChange(of: store.entries.count) { _, _ in
                scrollToLatest(using: proxy)
            }
            .onAppear {
                scrollToLatest(using: proxy)
            }
        }
    }

    @ViewBuilder
    private func row(for event: ChatEvent) -> some View {
        switch event {
        case .message(let message):
            ChatMessageRow(message: message, settings: settings)
        case .system(let message):
            systemMessageRow(message)
        }
    }

    private func systemMessageRow(_ message: SystemMessage) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if settings.showTimestamps {
                Text(Self.timestampFormatter.string(from: message.timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 48, alignment: .leading)
            }

            Text(message.text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scrollToLatest(using proxy: ScrollViewProxy) {
        guard !store.entries.isEmpty else { return }
        let lastIndex = store.entries.indices.last ?? 0
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastIndex, anchor: .bottom)
        }
    }
}

#Preview {
    let settings = ChatSettings()
    let store = ChatStore(settings: settings)
    store.append(event: .system(SystemMessage(text: "Connected", timestamp: Date(), kind: .notice, channel: nil)))
    store.append(event: .message(ChatMessage(
        id: "1",
        user: ChatUser(displayName: "kappa", login: "kappa"),
        text: "Hello https://twitch.tv",
        timestamp: Date(),
        receivedAt: Date(),
        channel: "dankchat"
    )))

    return ChatTimelineView(store: store, settings: settings)
        .padding()
}
