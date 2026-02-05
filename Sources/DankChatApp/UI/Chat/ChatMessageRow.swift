import SwiftUI
import DankChatCore

struct ChatMessageRow: View {
    let message: ChatMessage
    @ObservedObject var settings: ChatSettings

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if settings.showTimestamps {
                Text(Self.timestampFormatter.string(from: message.timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 48, alignment: .leading)
            }

            if settings.showUsernames {
                Text(message.user.displayName)
                    .font(.subheadline.weight(.semibold))
            }

            messageText
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var messageText: some View {
        let attributed = Self.attributedMessageText(message.text)
        return Text(attributed)
            .foregroundStyle(.primary)
            .italic(message.isAction)
    }

    private static func attributedMessageText(_ text: String) -> AttributedString {
        guard let detector = linkDetector else {
            return AttributedString(text)
        }

        let attributed = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: attributed.length)
        detector.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match, let url = match.url else { return }
            attributed.addAttribute(.link, value: url, range: match.range)
        }

        return AttributedString(attributed)
    }
}

#Preview {
    let settings = ChatSettings()
    let user = ChatUser(displayName: "kappa", login: "kappa")
    let message = ChatMessage(
        id: "1",
        user: user,
        text: "Hello https://twitch.tv",
        timestamp: Date(),
        receivedAt: Date(),
        channel: "dankchat"
    )

    return ChatMessageRow(message: message, settings: settings)
        .padding()
}
