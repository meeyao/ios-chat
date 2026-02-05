import SwiftUI
import DankChatCore

@main
struct DankChatApp: App {
    @StateObject private var authManager: AuthManager
    private let connectionSupervisor: IRCConnectionSupervisor
    private let configuration: AppConfiguration

    init() {
        let configuration = AppConfiguration.load()
        let tokenStore = KeychainTokenStore(
            service: configuration.keychainService,
            account: configuration.keychainAccount
        )
        let oauthClient = OAuthClient(configuration: configuration.oauthConfiguration)
        let authorizer = SystemOAuthAuthorizer()
        let authManager = AuthManager(
            configuration: configuration.oauthConfiguration,
            tokenStore: tokenStore,
            oauthClient: oauthClient,
            authorizer: authorizer
        )

        self.configuration = configuration
        self.connectionSupervisor = IRCConnectionSupervisor()
        _authManager = StateObject(wrappedValue: authManager)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                authManager: authManager,
                connectionSupervisor: connectionSupervisor,
                configuration: configuration
            )
        }
    }
}

private struct ContentView: View {
    @ObservedObject var authManager: AuthManager
    let connectionSupervisor: IRCConnectionSupervisor
    let configuration: AppConfiguration

    @StateObject private var chatSettings: ChatSettings
    @StateObject private var chatStore: ChatStore
    @StateObject private var connectionStore: ConnectionStatusStore
    @State private var chatSession: ChatSession?
    @State private var activeChannel: String
    @State private var didStartMonitoring = false

    init(authManager: AuthManager, connectionSupervisor: IRCConnectionSupervisor, configuration: AppConfiguration) {
        self.authManager = authManager
        self.connectionSupervisor = connectionSupervisor
        self.configuration = configuration

        let settings = ChatSettings()
        _chatSettings = StateObject(wrappedValue: settings)
        _chatStore = StateObject(wrappedValue: ChatStore(settings: settings))
        _connectionStore = StateObject(wrappedValue: connectionSupervisor.statusStore())
        _activeChannel = State(initialValue: configuration.defaultChannel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DankChat iOS")
                .font(.title2)
                .bold()

            if !configuration.isConfigured {
                Text("Update Config.plist with Twitch client info.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ConnectionStatusView(store: connectionStore)

            VStack(alignment: .leading, spacing: 8) {
                Text(authStateText)
                    .font(.subheadline)

                HStack {
                    Button("Sign In") {
                        Task { await authManager.beginLogin() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!configuration.isConfigured || isSigningIn)

                    Button("Sign Out") {
                        authManager.signOut()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isSignedIn)
                }
            }

            HStack {
                Button("Connect IRC") {
                    connectIRC()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isSignedIn || !configuration.isConfigured)

                Button("Disconnect") {
                    connectionSupervisor.disconnect(reason: "User requested")
                }
                .buttonStyle(.bordered)
            }

            ChatSettingsView(settings: chatSettings)

            ChatTimelineView(store: chatStore, settings: chatSettings)
                .frame(minHeight: 240)

            ChatComposerView(
                connectionStore: connectionStore,
                session: chatSession,
                channel: activeChannel
            )
        }
        .padding()
        .task {
            if !didStartMonitoring {
                didStartMonitoring = true
                connectionSupervisor.startMonitoring()
                authManager.restoreSession()
                await authManager.refreshIfNeeded()
            }
        }
    }

    private var isSigningIn: Bool {
        if case .signingIn = authManager.state { return true }
        return false
    }

    private var isSignedIn: Bool {
        if case .signedIn = authManager.state { return true }
        return false
    }

    private var authStateText: String {
        switch authManager.state {
        case .signedOut:
            return "Signed out"
        case .signingIn:
            return "Signing in..."
        case .signedIn(let token):
            return "Signed in (token: \(tokenPreview(token.accessToken)))"
        case .error(let message):
            return "Auth error: \(message)"
        }
    }

    private func tokenPreview(_ token: String) -> String {
        let prefix = token.prefix(6)
        return "\(prefix)..."
    }

    private func connectIRC() {
        guard case let .signedIn(token) = authManager.state else { return }
        let ircConfig = IRCConfiguration(
            nickname: configuration.defaultNick,
            user: configuration.defaultUser,
            oauthToken: token.accessToken
        )
        let channel = configuration.defaultChannel
        let channels = channel.isEmpty ? [] : [channel]
        activeChannel = channel
        chatSession = ChatSession(
            supervisor: connectionSupervisor,
            store: chatStore,
            settings: chatSettings,
            channel: channel.isEmpty ? nil : channel
        )
        connectionSupervisor.connect(configuration: ircConfig, channels: channels)
    }
}
