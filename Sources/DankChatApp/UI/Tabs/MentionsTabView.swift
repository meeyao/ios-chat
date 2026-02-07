import SwiftUI
import DankChatCore

/// Displays the mentions timeline using the social tab store's mentions chat store.
struct MentionsTabView: View {
    @EnvironmentObject private var socialTabStore: SocialTabStore
    @ObservedObject var settings: ChatSettings
    @State private var isAtBottom: Bool = true
    @State private var lastReadMessageId: String?

    var body: some View {
        Group {
            if socialTabStore.mentionsStore.entries.isEmpty {
                emptyState
            } else {
                ChatTimelineView(
                    store: socialTabStore.mentionsStore,
                    settings: settings,
                    isAtBottom: $isAtBottom,
                    lastReadMessageId: $lastReadMessageId
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No mentions yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Messages that mention you will appear here.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
