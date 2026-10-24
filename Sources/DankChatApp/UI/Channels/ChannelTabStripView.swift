import SwiftUI
import DankChatCore

struct ChannelTabStripView: View {
    @ObservedObject var store: ChannelStore
    @Binding var selection: String?

    let connectionState: (Channel) -> IRCConnectionState
    let onRename: (Channel, String) -> Void
    let onRemove: (Channel) -> Void
    let onTogglePin: (Channel) -> Void
    let onReconnect: (Channel) -> Void

    @State private var renameTarget: Channel?
    @State private var renameText = ""
    @State private var removeTarget: Channel?
    @State private var showRenamePrompt = false
    @State private var showRemovePrompt = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(store.channels) { channel in
                    Button {
                        selection = channel.id
                        store.setActive(id: channel.id)
                    } label: {
                        let state = store.state(for: channel.id) ?? ChannelState()
                        VStack(spacing: 4) {
                            HStack(spacing: 5) {
                                Text(channel.displayName)
                                    .font(.subheadline.weight(isActive(channel) ? .semibold : .regular))
                                    .lineLimit(1)
                                if state.mentionCount > 0 {
                                    MentionBadge(count: state.mentionCount)
                                } else if state.unreadCount > 0 {
                                    UnreadDot()
                                }
                            }
                            .foregroundStyle(isActive(channel) ? Color.primary : Color.secondary)

                            Rectangle()
                                .fill(isActive(channel) ? Color.accentColor : Color.clear)
                                .frame(height: 2)
                                .clipShape(Capsule())
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(channel.isPinned ? "Unpin" : "Pin") {
                            onTogglePin(channel)
                        }
                        Button("Rename") {
                            renameTarget = channel
                            renameText = channel.displayName
                            showRenamePrompt = true
                        }
                        Button("Remove", role: .destructive) {
                            requestRemove(channel)
                        }
                        Button("Reconnect now") {
                            onReconnect(channel)
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .alert("Rename Channel", isPresented: $showRenamePrompt) {
            TextField("Channel name", text: $renameText)
            Button("Rename") {
                guard let target = renameTarget else { return }
                onRename(target, renameText)
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Remove Channel", isPresented: $showRemovePrompt) {
            Button("Remove", role: .destructive) {
                if let target = removeTarget {
                    onRemove(target)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove this channel? Local history will be kept.")
        }
    }

    private func requestRemove(_ channel: Channel) {
        if store.hasHistory(id: channel.id) {
            removeTarget = channel
            showRemovePrompt = true
        } else {
            onRemove(channel)
        }
    }

    private func isActive(_ channel: Channel) -> Bool {
        channel.id == selection || channel.id == store.activeChannelId
    }
}

private struct UnreadDot: View {
    var body: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 8, height: 8)
            .accessibilityLabel("Unread messages")
    }
}

private struct MentionBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.caption2)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.red)
            .clipShape(Capsule())
            .accessibilityLabel("\(count) mentions")
    }
}

#Preview {
    let settings = ChatSettings()
    let store = ChannelStore(settings: settings)
    store.addChannel(name: "dankchat")
    store.addChannel(name: "swiftlang")
    store.setPinned(id: "dankchat", isPinned: true)

    return ChannelTabStripView(
        store: store,
        selection: .constant("dankchat"),
        connectionState: { _ in .connected },
        onRename: { _, _ in },
        onRemove: { _ in },
        onTogglePin: { _ in },
        onReconnect: { _ in }
    )
    .padding()
}
