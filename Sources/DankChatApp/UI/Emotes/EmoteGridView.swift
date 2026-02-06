import SwiftUI
import DankChatCore

struct EmoteGridView: View {
    let emotes: [Emote]
    let onSelect: (Emote) -> Void

    private let columns = [GridItem(.adaptive(minimum: 44, maximum: 72), spacing: 8)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(emotes) { emote in
                    Button {
                        onSelect(emote)
                    } label: {
                        emoteCell(for: emote)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func emoteCell(for emote: Emote) -> some View {
        AsyncImage(url: emote.imageURLs.preferred) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 36, height: 36)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
            case .failure:
                Image(systemName: "face.smiling")
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.secondary)
            @unknown default:
                Color.clear
                    .frame(width: 36, height: 36)
            }
        }
        .accessibilityLabel(Text(emote.code))
    }
}
