import SwiftUI
import DankChatCore

struct ChatComposerView: View {
    @ObservedObject var connectionStore: ConnectionStatusStore
    let session: ChatSession?
    let channel: String

    @State private var messageText = ""

    var body: some View {
        HStack(spacing: 12) {
            TextField("Send a message", text: $messageText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .submitLabel(.send)
                .onSubmit {
                    sendMessage()
                }

            Button("Send") {
                sendMessage()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSend)
        }
    }

    private var canSend: Bool {
        session != nil && isConnected && !trimmedMessage.isEmpty
    }

    private var trimmedMessage: String {
        messageText.trimmingCharacters(in: .whitespacesAndNewlines)
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
        messageText = ""
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
