import SwiftUI
import DankChatCore

struct ChannelManagementView: View {
    @ObservedObject var store: ChannelStore

    let onJoin: (String) -> Void
    let onPart: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var joinName = ""
    @State private var showJoinPrompt = false
    @State private var renameTarget: Channel?
    @State private var renameText = ""
    @State private var showRenamePrompt = false
    @State private var removeTarget: Channel?
    @State private var showRemovePrompt = false

    var body: some View {
        NavigationStack {
            List {
                if !pinned.isEmpty {
                    Section("Pinned") {
                        ForEach(pinned) { channel in
                            row(for: channel)
                        }
                    }
                }

                Section("Channels") {
                    ForEach(unpinned) { channel in
                        row(for: channel)
                    }
                    .onMove { offsets, destination in
                        store.moveUnpinned(fromOffsets: offsets, toOffset: destination)
                    }
                }
            }
            .navigationTitle("Manage Channels")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showJoinPrompt = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Join Channel", isPresented: $showJoinPrompt) {
                TextField("Channel name", text: $joinName)
                Button("Join") {
                    handleJoin()
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Rename Channel", isPresented: $showRenamePrompt) {
                TextField("Channel name", text: $renameText)
                Button("Rename") {
                    handleRename()
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Remove Channel", isPresented: $showRemovePrompt) {
                Button("Remove", role: .destructive) {
                    if let target = removeTarget {
                        remove(channel: target)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Remove this channel? Local history will be kept.")
            }
        }
    }

    private var pinned: [Channel] {
        store.channels.filter { $0.isPinned }
    }

    private var unpinned: [Channel] {
        store.channels.filter { !$0.isPinned }
    }

    private func row(for channel: Channel) -> some View {
        HStack(spacing: 8) {
            Text(channel.displayName)
                .lineLimit(1)
            if channel.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(channel.isPinned ? "Unpin" : "Pin") {
                store.setPinned(id: channel.id, isPinned: !channel.isPinned)
            }
            Button("Rename") {
                renameTarget = channel
                renameText = channel.displayName
                showRenamePrompt = true
            }
            Button("Remove", role: .destructive) {
                requestRemove(channel)
            }
        }
    }

    private func handleJoin() {
        let normalized = Channel.normalizeId(joinName)
        guard !normalized.isEmpty else { return }
        store.addChannel(name: joinName)
        onJoin(normalized)
        joinName = ""
    }

    private func handleRename() {
        guard let target = renameTarget else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let oldId = target.id
        onPart(oldId)
        store.renameChannel(id: oldId, newName: trimmed)
        let normalized = Channel.normalizeId(trimmed)
        if !normalized.isEmpty {
            onJoin(normalized)
        }
    }

    private func requestRemove(_ channel: Channel) {
        if store.hasHistory(id: channel.id) {
            removeTarget = channel
            showRemovePrompt = true
        } else {
            remove(channel: channel)
        }
    }

    private func remove(channel: Channel) {
        store.removeChannel(id: channel.id)
        onPart(channel.id)
    }
}

#Preview {
    let settings = ChatSettings()
    let store = ChannelStore(settings: settings)
    store.addChannel(name: "dankchat")
    store.addChannel(name: "swiftlang")
    store.setPinned(id: "dankchat", isPinned: true)
    return ChannelManagementView(
        store: store,
        onJoin: { _ in },
        onPart: { _ in }
    )
}
