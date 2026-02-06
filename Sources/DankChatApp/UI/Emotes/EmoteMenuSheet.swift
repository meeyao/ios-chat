import SwiftUI
import DankChatCore

struct EmoteMenuSheet: View {
    enum Tab: String, CaseIterable, Identifiable {
        case recents
        case twitch
        case sevenTV
        case bttv
        case ffz
        case emoji

        var id: String { rawValue }

        var title: String {
            switch self {
            case .recents: return "Recents"
            case .twitch: return "Twitch"
            case .sevenTV: return "7TV"
            case .bttv: return "BTTV"
            case .ffz: return "FFZ"
            case .emoji: return "Emoji"
            }
        }
    }

    @EnvironmentObject private var emoteStore: EmoteStore
    @ObservedObject var recentsStore: EmoteRecentsStore
    @ObservedObject var settings: EmoteMenuSettings
    let channelLogin: String?
    let onInsertText: (String) -> Void

    @State private var selectedTab: Tab = .recents
    @State private var searchText = ""

    private let emojiList: [String] = [
        "😀", "😄", "😁", "😆", "🤣", "😂", "🙂", "😉", "😍", "😘",
        "😎", "🤩", "🥳", "🤔", "😴", "😭", "😡", "😱", "🙏", "👏",
        "👍", "👎", "🔥", "✨", "💯", "🎉", "🎮", "🍿", "☕", "💜"
    ]

    var body: some View {
        VStack(spacing: 12) {
            searchField
            tabBar

            if selectedTab == .recents {
                orderingPicker
            }

            contentView
        }
        .padding(.top, 12)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search emotes", text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal, 12)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Tab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.title)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    private var orderingPicker: some View {
        Picker("Ordering", selection: $settings.recentsOrdering) {
            ForEach(EmoteMenuSettings.RecentsOrdering.allCases, id: \.self) { ordering in
                Text(ordering.displayName).tag(ordering)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .recents:
            emoteGrid(for: filteredRecents)
        case .twitch:
            emoteGrid(for: filteredProvider(.twitch))
        case .sevenTV:
            emoteGrid(for: filteredProvider(.sevenTV))
        case .bttv:
            emoteGrid(for: filteredProvider(.bttv))
        case .ffz:
            emoteGrid(for: filteredProvider(.ffz))
        case .emoji:
            emojiGrid
        }
    }

    private func emoteGrid(for emotes: [Emote]) -> some View {
        Group {
            if emotes.isEmpty {
                emptyState
            } else {
                EmoteGridView(emotes: emotes) { emote in
                    recentsStore.recordUse(emote: emote)
                    onInsertText(emote.code)
                }
            }
        }
    }

    private var emojiGrid: some View {
        let emojis = filteredEmoji
        return Group {
            if emojis.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 72), spacing: 8)], spacing: 10) {
                        ForEach(emojis, id: \.self) { emoji in
                            Button {
                                onInsertText(emoji)
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 28))
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "face.dashed")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No emotes found")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filteredRecents: [Emote] {
        filter(emotes: recentsStore.orderedRecents(ordering: settings.recentsOrdering))
    }

    private func filteredProvider(_ provider: ProviderID) -> [Emote] {
        filter(emotes: emoteStore.emotes(for: provider, channelLogin: channelLogin))
    }

    private func filter(emotes: [Emote]) -> [Emote] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return emotes }
        return emotes.filter { $0.code.localizedCaseInsensitiveContains(query) }
    }

    private var filteredEmoji: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return emojiList }
        return emojiList.filter { $0.localizedCaseInsensitiveContains(query) }
    }
}
