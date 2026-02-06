import SwiftUI
import DankChatCore

struct ChatMessageRow: View {
    let message: ChatMessage
    @ObservedObject var settings: ChatSettings
    @EnvironmentObject private var emoteStore: EmoteStore

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

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

            ChatRichTextView(message: message, settings: settings, emoteStore: emoteStore)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let settings = ChatSettings()
    let configuration = OAuthConfiguration(clientId: "", redirectURI: "", scopes: [])
    let twitchProvider = TwitchEmoteProvider(configuration: configuration, tokenProvider: { nil })
    let emoteStore = EmoteStore(
        twitchProvider: twitchProvider,
        bttvProvider: BTTVEmoteProvider(),
        ffzProvider: FFZEmoteProvider(),
        sevenTVProvider: SevenTVEmoteProvider()
    )
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
        .environmentObject(emoteStore)
        .padding()
}
