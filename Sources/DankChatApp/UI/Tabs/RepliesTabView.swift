import SwiftUI
import DankChatCore

/// Displays the replies timeline using the social tab store's replies chat store.
struct RepliesTabView: View {
    @EnvironmentObject private var socialTabStore: SocialTabStore
    @ObservedObject var settings: ChatSettings
    @State private var isAtBottom: Bool = true
    @State private var lastReadMessageId: String?

    var body: some View {
        Group {
            if socialTabStore.repliesStore.entries.isEmpty {
                emptyState
            } else {
                ChatTimelineView(
                    store: socialTabStore.repliesStore,
                    settings: settings,
                    isAtBottom: $isAtBottom,
                    lastReadMessageId: $lastReadMessageId
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No replies yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Replies to your messages will appear here.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
