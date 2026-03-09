import SwiftUI
import DankChatCore

struct ChatTimelineView: View {
    @ObservedObject var store: ChatStore
    @ObservedObject var settings: ChatSettings
    @Binding var isAtBottom: Bool
    @Binding var lastReadMessageId: String?

    @State private var scrollViewHeight: CGFloat = 0
    @State private var didRestorePosition = false

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
                        let event = store.entries[index]
                        let entryId = entryId(for: index, event: event)
                        row(for: event)
                            .id(entryId)
                            .background(
                                GeometryReader { geometry in
                                    Color.clear.preference(
                                        key: VisibleEntryPreferenceKey.self,
                                        value: [
                                            VisibleEntry(
                                                id: entryId,
                                                minY: geometry.frame(in: .named("scroll")).minY,
                                                maxY: geometry.frame(in: .named("scroll")).maxY
                                            )
                                        ]
                                    )
                                }
                            )
                    }
                    Color.clear
                        .frame(height: 1)
                        .background(
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: BottomAnchorPreferenceKey.self,
                                    value: geometry.frame(in: .named("scroll")).maxY
                                )
                            }
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onChange(of: store.entries.count) { _, _ in
                if isAtBottom {
                    scrollToLatest(using: proxy)
                }
            }
            .onAppear {
                restoreScroll(using: proxy)
            }
            .coordinateSpace(.named("scroll"))
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollViewHeightPreferenceKey.self,
                        value: geometry.size.height
                    )
                }
            )
            .onPreferenceChange(ScrollViewHeightPreferenceKey.self) { height in
                if abs(scrollViewHeight - height) > 0.1 {
                    scrollViewHeight = height
                }
            }
            .onPreferenceChange(BottomAnchorPreferenceKey.self) { bottomMaxY in
                guard scrollViewHeight > 0 else { return }
                let atBottom = bottomMaxY <= scrollViewHeight + 10
                if isAtBottom != atBottom {
                    isAtBottom = atBottom
                }
            }
            .onPreferenceChange(VisibleEntryPreferenceKey.self) { entries in
                updateLastRead(using: entries)
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
        guard let lastId = latestEntryId() else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }

    private func restoreScroll(using proxy: ScrollViewProxy) {
        guard !didRestorePosition else { return }
        didRestorePosition = true
        let targetId = lastReadMessageId ?? latestEntryId()
        guard let targetId else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(targetId, anchor: .bottom)
        }
    }

    private func latestEntryId() -> String? {
        guard let index = store.entries.indices.last else { return nil }
        return entryId(for: index, event: store.entries[index])
    }

    private func entryId(for index: Int, event: ChatEvent) -> String {
        if let messageId = event.messageId {
            return messageId
        }
        return "event-\(index)"
    }

    private func updateLastRead(using entries: [VisibleEntry]) {
        guard scrollViewHeight > 0 else { return }
        if isAtBottom {
            let latestId = latestEntryId()
            if lastReadMessageId != latestId {
                lastReadMessageId = latestId
            }
            return
        }

        let visible = entries.filter { $0.maxY >= 0 && $0.minY <= scrollViewHeight }
        guard let lastVisible = visible.max(by: { $0.maxY < $1.maxY }) else { return }
        if lastReadMessageId != lastVisible.id {
            lastReadMessageId = lastVisible.id
        }
    }
}

private struct VisibleEntry: Equatable {
    let id: String
    let minY: CGFloat
    let maxY: CGFloat
}

private struct VisibleEntryPreferenceKey: PreferenceKey {
    static let defaultValue: [VisibleEntry] = []

    static func reduce(value: inout [VisibleEntry], nextValue: () -> [VisibleEntry]) {
        value.append(contentsOf: nextValue())
    }
}

private struct BottomAnchorPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScrollViewHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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

    return ChatTimelineView(
        store: store,
        settings: settings,
        isAtBottom: .constant(true),
        lastReadMessageId: .constant(nil)
    )
        .padding()
}
