import SwiftUI
import UIKit
import DankChatCore

struct ChatComposerView: View {
    @ObservedObject var connectionStore: ConnectionStatusStore
    let session: ChatSession?
    let channel: String

    @EnvironmentObject private var emoteStore: EmoteStore

    @State private var messageText = ""
    @State private var selection = NSRange(location: 0, length: 0)
    @State private var isShowingEmoteMenu = false
    @StateObject private var recentsStore = EmoteRecentsStore()
    @StateObject private var menuSettings = EmoteMenuSettings()

    private let suggestionEngine = EmoteSuggestionEngine()

    var body: some View {
        VStack(spacing: 8) {
            if !suggestions.isEmpty {
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

                ComposerTextView(text: $messageText, selection: $selection) {
                    sendMessage()
                }
                .frame(minHeight: 36, maxHeight: 96)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separator))
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
    }

    private var canSend: Bool {
        session != nil && isConnected && !trimmedMessage.isEmpty
    }

    private var trimmedMessage: String {
        messageText.trimmingCharacters(in: .whitespacesAndNewlines)
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
        if case .connected = connectionStore.state {
            return true
        }
        return false
    }

    private func sendMessage() {
        guard canSend else { return }
        session?.sendMessage(text: trimmedMessage, channel: channel)
        recentsStore.recordEmotes(in: trimmedMessage, emoteStore: emoteStore, channelLogin: channel)
        messageText = ""
        selection = NSRange(location: 0, length: 0)
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
}

private struct ComposerTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    let onCommit: () -> Void

    func makeUIView(context: Context) -> UITextView {
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

    func updateUIView(_ uiView: UITextView, context: Context) {
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

#Preview {
    let settings = ChatSettings()
    let store = ChatStore(settings: settings)
    let supervisor = IRCConnectionSupervisor()
    let session = ChatSession(supervisor: supervisor, store: store, settings: settings)
    let connectionStore = supervisor.statusStore()

    return ChatComposerView(connectionStore: connectionStore, session: session, channel: "dankchat")
        .padding()
}
