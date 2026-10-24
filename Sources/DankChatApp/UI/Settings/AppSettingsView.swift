import SwiftUI
import DankChatCore

/// The top-level settings sheet.
struct AppSettingsView: View {
    @EnvironmentObject private var commandStore: CommandStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Twitch") {
                    NavigationLink("Twitch Login") {
                        TwitchLoginSettingsView()
                    }
                }

                Section("Chat") {
                    NavigationLink("Appearance") {
                        AppearanceSettingsView()
                    }
                    NavigationLink("Notifications & Highlights") {
                        NotificationsSettingsView()
                    }
                    NavigationLink("Tools & Streams") {
                        ToolsSettingsView()
                    }
                    NavigationLink("Commands") {
                        CommandManagementView(commandStore: commandStore)
                    }
                }

                Section("About") {
                    NavigationLink("About DankChat") {
                        AboutView()
                    }
                    NavigationLink("Changelog") {
                        ChangelogView()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

extension ChatThemePreference {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct AppearanceSettingsView: View {
    @EnvironmentObject private var settings: ChatSettings

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Theme", selection: $settings.theme) {
                    ForEach(ChatThemePreference.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("True Dark", isOn: $settings.trueDarkTheme)
            }

            Section {
                Stepper("Font size: \(settings.fontSize)", value: $settings.fontSize, in: 10...28)
                Toggle("Line separators", isOn: $settings.lineSeparator)
                Toggle("Checkered messages", isOn: $settings.checkeredMessages)
                Toggle("Keep screen on", isOn: $settings.keepScreenOn)
            } header: {
                Text("Display")
            }

            Section {
                Toggle("Show input", isOn: $settings.showInput)
                Toggle("Auto-disable input", isOn: $settings.autoDisableInput)
                    .disabled(!settings.showInput)
                Toggle("Show info chips", isOn: $settings.showChips)
                Toggle("Show changelogs", isOn: $settings.showChangelogs)
            } header: {
                Text("Components")
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    @AppStorage("secretDankerMode") private var dankerMode = false
    @State private var versionTaps = 0

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DankChat for iOS")
                        .font(.title2.weight(.bold))
                    Text("A native SwiftUI port of DankChat for Twitch chat.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Version \(version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .onTapGesture {
                            versionTaps += 1
                            if versionTaps >= 10 {
                                dankerMode.toggle()
                                versionTaps = 0
                            }
                        }
                }
                .padding(.vertical, 4)
            }

            if dankerMode {
                Section {
                    Label("Secret Danker Mode enabled", systemImage: "sparkles")
                        .foregroundStyle(.pink)
                }
            }

            Section("Links") {
                Link("DankChat on GitHub", destination: URL(string: "https://github.com/flex3r/DankChat")!)
                Link("Chatterino on GitHub", destination: URL(string: "https://github.com/Chatterino/chatterino2")!)
            }

            Section("License") {
                Text("This project is a GPL-compatible port of DankChat. DankChat and Chatterino are licensed under GPL-3.0.")
                    .font(.footnote)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TwitchLoginSettingsView: View {
    @AppStorage("twitch.clientId") private var savedClientId = ""
    @EnvironmentObject private var authManager: AuthManager
    @State private var draft = ""

    var body: some View {
        Form {
            Section("Account") {
                switch authManager.state {
                case .signedIn(let token):
                    Text("Signed in (\(token.scope.count) scopes)")
                        .foregroundStyle(.secondary)
                    Button("Sign Out", role: .destructive) {
                        authManager.signOut()
                    }
                case .signingIn:
                    Text("Waiting for Twitch authorization...")
                        .foregroundStyle(.secondary)
                case .signedOut:
                    Text("Signed out")
                        .foregroundStyle(.secondary)
                case .error(let message):
                    Text(message)
                        .foregroundStyle(.red)
                }
            }

            Section {
                TextField("Twitch Client ID", text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Save Client ID") {
                    savedClientId = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !savedClientId.isEmpty {
                    Button("Clear Client ID", role: .destructive) {
                        savedClientId = ""
                        draft = ""
                    }
                }
            } footer: {
                Text("Create an app at dev.twitch.tv/console/apps, copy its Client ID, and paste it here. No client secret or redirect URL is needed. Restart the app after saving, then tap Sign In and enter the code at twitch.tv/activate.")
            }
        }
        .navigationTitle("Twitch Login")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            draft = savedClientId
        }
    }
}

struct DeviceLoginView: View {
    let prompt: AuthManager.DeviceLoginPrompt
    let onCancel: () -> Void
    @State private var showActivationPage = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Log in to Twitch")
                    .font(.title2.weight(.bold))

                Text("Enter this code on Twitch:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(prompt.userCode)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .textSelection(.enabled)

                Button {
                    showActivationPage = true
                } label: {
                    Label("Open twitch.tv/activate", systemImage: "safari")
                }
                .buttonStyle(.borderedProminent)

                ProgressView("Waiting for authorization...")

                Text("Keep this app open while you authorize. It signs in automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Cancel", role: .cancel) {
                    onCancel()
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
        .sheet(isPresented: $showActivationPage) {
            SafariView(url: prompt.verificationURI)
                .ignoresSafeArea()
        }
    }
}

struct ChangelogView: View {
    private let entries: [(version: String, notes: [String])] = [
        ("0.2.2", [
            "Full OAuth scopes for profile, moderation, and whispers",
            "All channels now update unread counts and notifications",
            "Chat events routed on the main actor",
            "Compact DankChat-style composer"
        ]),
        ("0.2.1", [
            "Fixed appearance crash (missing environment object)",
            "Device login survives the Twitch activation hand-off",
            "IRC authenticates only after the WebSocket opens",
            "Chat-first layout on iPhone with jump-to-bottom"
        ]),
        ("0.2.0", [
            "Twitch device-code login and in-app Client ID",
            "Fixed phone layout so chat scrolls",
            "Single active channel view on iPhone"
        ]),
        ("0.1.0", [
            "Native iOS app target and GitHub Actions build",
            "Highlights, ignored users, and local notifications",
            "Stream info/player, image uploads, and text to speech",
            "Persisted appearance and chat settings"
        ])
    ]

    var body: some View {
        List {
            ForEach(entries, id: \.version) { entry in
                Section("Version \(entry.version)") {
                    ForEach(entry.notes, id: \.self) { note in
                        Text(note)
                            .font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle("Changelog")
        .navigationBarTitleDisplayMode(.inline)
    }
}
