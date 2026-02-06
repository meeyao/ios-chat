import SwiftUI
import DankChatCore

struct ChannelListView: View {
    @ObservedObject var store: ChannelStore
    @Binding var selection: String?

    let connectionState: (Channel) -> IRCConnectionState
    let onRename: (Channel, String) -> Void
    let onRemove: (Channel) -> Void
    let onTogglePin: (Channel) -> Void
    let onReconnect: (Channel) -> Void
    let onManage: () -> Void

    @State private var renameTarget: Channel?
    @State private var renameText = ""
    @State private var removeTarget: Channel?
    @State private var showRenamePrompt = false
    @State private var showRemovePrompt = false

    var body: some View {
        List(selection: $selection) {
            ForEach(store.channels) { channel in
                row(for: channel)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onManage()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
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

    private func row(for channel: Channel) -> some View {
        let state = store.state(for: channel.id) ?? ChannelState()
        return HStack(spacing: 8) {
            Text(channel.displayName)
                .lineLimit(1)
            if channel.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if state.mentionCount > 0 {
                MentionBadge(count: state.mentionCount)
            }
            if state.unreadCount > 0 {
                UnreadDot()
            }
            ChannelStatusIndicator(state: connectionState(channel))
        }
        .tag(channel.id)
        .contentShape(Rectangle())
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
        .onTapGesture {
            selection = channel.id
            store.setActive(id: channel.id)
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
    return ChannelListView(
        store: store,
        selection: .constant("dankchat"),
        connectionState: { _ in .connected },
        onRename: { _, _ in },
        onRemove: { _ in },
        onTogglePin: { _ in },
        onReconnect: { _ in },
        onManage: {}
    )
}
