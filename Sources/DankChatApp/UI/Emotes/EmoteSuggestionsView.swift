import SwiftUI
import DankChatCore

struct EmoteSuggestionsView: View {
    let suggestions: [Emote]
    let onSelect: (Emote) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(suggestions.indices, id: \.self) { index in
                let emote = suggestions[index]
                Button {
                    onSelect(emote)
                } label: {
                    suggestionRow(for: emote)
                }
                .buttonStyle(.plain)

                if index < suggestions.count - 1 {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separator))
        )
    }

    private func suggestionRow(for emote: Emote) -> some View {
        HStack(spacing: 8) {
            AsyncImage(url: emote.imageURLs.preferred) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 28, height: 28)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                case .failure:
                    Image(systemName: "face.smiling")
                        .frame(width: 28, height: 28)
                        .foregroundStyle(.secondary)
                @unknown default:
                    Color.clear
                        .frame(width: 28, height: 28)
                }
            }
            Text(emote.code)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .accessibilityLabel(Text(emote.code))
    }
}
