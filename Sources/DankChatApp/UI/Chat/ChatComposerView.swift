#if canImport(UIKit)
import UIKit
#endif
import DankChatCore
import Combine
import SwiftUI

@MainActor
struct ChatComposerView: View {
    @ObservedObject var connectionStore: ConnectionStatusStore
    let session: ChatSession?
    let channel: String

    @EnvironmentObject private var emoteStore: EmoteStore
    @EnvironmentObject private var identityStore: UserIdentityStore
    @EnvironmentObject private var commandStore: CommandStore

    @State private var messageText = ""
    @State private var selection = NSRange(location: 0, length: 0)
    @State private var isShowingEmoteMenu = false
    @State private var isShowingCommandManagement = false
    @State private var commandSuggestions: [CommandSuggestion] = []
    @State private var commandSuggestionTask: Task<Void, Never>?
    @StateObject private var recentsStore = EmoteRecentsStore()
    @StateObject private var menuSettings = EmoteMenuSettings()

    private let suggestionEngine = EmoteSuggestionEngine()
    private let commandResolver = CommandResolver()
    private let commandSuggestionsClient = CommandSuggestionsClient()

    public init(connectionStore: ConnectionStatusStore, session: ChatSession?, channel: String) {
        self.connectionStore = connectionStore
        self.session = session
        self.channel = channel
    }

    var body: some View {
        VStack(spacing: 8) {
            if shouldShowCommandSuggestions {
                CommandSuggestionsListView(suggestions: commandSuggestions) { suggestion in
                    applyCommandSuggestion(suggestion)
                }
            } else if !suggestions.isEmpty {
                EmoteSuggestionsView(suggestions: suggestions) { emote in
                    applySuggestion(emote)
                }
            }

            HStack(spacing: 12) {
                Button {
                    isShowingEmoteMenu = true
                } label: {
                    Image(systemName: "face.smiling")
                        .font(.title3)
                }
                .buttonStyle(.bordered)

                Button {
                    isShowingCommandManagement = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                }
                .buttonStyle(.bordered)

                ComposerTextView(text: $messageText, selection: $selection) {
                    sendMessage()
                }
                .frame(minHeight: 36, maxHeight: 96)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2))
                )

                Button("Send") {
                    sendMessage()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSend)
            }
        }
        .sheet(isPresented: $isShowingEmoteMenu) {
            EmoteMenuSheet(
                recentsStore: recentsStore,
                settings: menuSettings,
                channelLogin: channel
            ) { insertion in
                insertText(insertion)
            }
            .environmentObject(emoteStore)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingCommandManagement) {
            CommandManagementView(commandStore: commandStore)
        }
        .onChange(of: messageText) { _, newValue in
            scheduleCommandSuggestions(for: newValue)
        }
        .onChange(of: identityStore.user?.login ?? "") { _, _ in
            scheduleCommandSuggestions(for: messageText)
        }
    }

    private var canSend: Bool {
        session != nil && isConnected && !trimmedMessage.isEmpty
    }

    private var trimmedMessage: String {
        messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shouldShowCommandSuggestions: Bool {
        trimmedMessage.hasPrefix("/") && !commandSuggestions.isEmpty
    }

    private var suggestions: [Emote] {
        let cursor = selection.location
        guard let token = EmoteTokenization.currentToken(in: messageText, cursor: cursor) else {
            return []
        }
        return suggestionEngine.suggestions(for: token, emotes: suggestionEmotes, limit: 5)
    }

    private var suggestionEmotes: [Emote] {
        var seen: Set<String> = []
        var merged: [Emote] = []
        for provider in ProviderID.allCases {
            let emotes = emoteStore.emotes(for: provider, channelLogin: channel)
            for emote in emotes {
                guard !seen.contains(emote.code) else { continue }
                seen.insert(emote.code)
                merged.append(emote)
            }
        }
        return merged
    }

    private var isConnected: Bool {
        connectionStore.status == .connected
    }

    private func sendMessage() {
        guard canSend else { return }
        let resolved = commandResolver.resolve(
            text: trimmedMessage,
            commands: commandStore.commands,
            context: CommandResolver.Context(
                channel: channel,
                user: currentUsername
            )
        )
        session?.sendMessage(text: resolved, channel: channel)
        recentsStore.recordEmotes(in: resolved, emoteStore: emoteStore, channelLogin: channel)
        messageText = ""
        selection = NSRange(location: 0, length: 0)
        commandSuggestions = []
    }

    private var currentUsername: String {
        if let user = identityStore.user {
            return user.displayName.isEmpty ? user.login : user.displayName
        }
        return "user"
    }

    private func insertText(_ text: String) {
        let current = messageText as NSString
        let safeLocation = min(selection.location, current.length)
        let safeLength = min(selection.length, current.length - safeLocation)
        let range = NSRange(location: safeLocation, length: safeLength)
        let updated = current.replacingCharacters(in: range, with: text)
        messageText = updated
        let newLocation = safeLocation + (text as NSString).length
        selection = NSRange(location: newLocation, length: 0)
    }

    private func applySuggestion(_ emote: Emote) {
        guard let token = EmoteTokenization.currentToken(in: messageText, cursor: selection.location) else {
            return
        }
        guard let updated = EmoteTokenization.replacingToken(
            in: messageText,
            token: token,
            with: emote.code,
            appendSpace: true
        ) else {
            return
        }
        messageText = updated.text
        selection = NSRange(location: updated.cursor, length: 0)
    }

    private func applyCommandSuggestion(_ suggestion: CommandSuggestion) {
        guard let slashIndex = messageText.firstIndex(of: "/") else { return }
        let endIndex = messageText.firstIndex(where: { $0.isWhitespace }) ?? messageText.endIndex
        let start = messageText.distance(from: messageText.startIndex, to: slashIndex)
        let length = messageText.distance(from: slashIndex, to: endIndex)
        let range = NSRange(location: start, length: length)
        let updated = (messageText as NSString).replacingCharacters(in: range, with: suggestion.insertion)
        messageText = updated
        selection = NSRange(location: start + (suggestion.insertion as NSString).length, length: 0)
        commandSuggestions = []
    }

    private func scheduleCommandSuggestions(for input: String) {
        commandSuggestionTask?.cancel()
        guard input.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/") else {
            commandSuggestions = []
            return
        }
        let currentInput = input
        let user = identityStore.user?.login
        commandSuggestionTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            let suggestions: [CommandSuggestion]
            do {
                suggestions = try await commandSuggestionsClient.suggestions(for: currentInput, user: user)
            } catch {
                suggestions = []
            }
            await MainActor.run {
                commandSuggestions = suggestions
            }
        }
    }
}

#if canImport(UIKit)
private struct ComposerTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    let onCommit: () -> Void

    @MainActor func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.isScrollEnabled = false
        textView.returnKeyType = .send
        textView.text = text
        return textView
    }

    @MainActor func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if uiView.selectedRange != selection {
            uiView.selectedRange = selection
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selection: $selection, onCommit: onCommit)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private var text: Binding<String>
        private var selection: Binding<NSRange>
        private let onCommit: () -> Void

        init(text: Binding<String>, selection: Binding<NSRange>, onCommit: @escaping () -> Void) {
            self.text = text
            self.selection = selection
            self.onCommit = onCommit
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            selection.wrappedValue = textView.selectedRange
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" {
                onCommit()
                return false
            }
            return true
        }
    }
}
#else
private struct ComposerTextView: View {
    @Binding var text: String
    @Binding var selection: NSRange
    let onCommit: () -> Void

    var body: some View {
        TextField("", text: $text)
    }
}
#endif

#Preview {
    let connectionStore = ConnectionStatusStore()
    
    return ChatComposerView(connectionStore: connectionStore, session: nil, channel: "dankchat")
        .padding()
        .environmentObject(UserIdentityStore(usersService: HelixUsersService(client: HelixAPIClient(clientId: "", tokenProvider: { nil }))))
        .environmentObject(CommandStore())
        .environmentObject(EmoteStore(twitchProvider: TwitchEmoteProvider(configuration: OAuthConfiguration(clientId: "", redirectURI: "", scopes: []), tokenProvider: { nil }), bttvProvider: BTTVEmoteProvider(), ffzProvider: FFZEmoteProvider(), sevenTVProvider: SevenTVEmoteProvider(), providerStatus: ProviderStatusStore()))
        .environmentObject(EmoteRecentsStore())
        .environmentObject(EmoteMenuSettings())
}
