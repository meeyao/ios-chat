import SwiftUI
import DankChatCore

struct CommandSuggestionsListView: View {
    let suggestions: [CommandSuggestion]
    let onSelect: (CommandSuggestion) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(suggestions.indices, id: \.self) { index in
                let suggestion = suggestions[index]
                Button {
                    onSelect(suggestion)
                } label: {
                    suggestionRow(for: suggestion)
                }
                .buttonStyle(.plain)

                if index < suggestions.count - 1 {
                    Divider()
                        .padding(.leading, 12)
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

    private func suggestionRow(for suggestion: CommandSuggestion) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "command")
                .frame(width: 20, height: 20)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.command)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let description = suggestion.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .accessibilityLabel(Text(suggestion.command))
    }
}
