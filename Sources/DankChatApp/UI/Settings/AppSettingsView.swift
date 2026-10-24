import SwiftUI
import DankChatCore

/// The top-level settings sheet.
struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
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

struct ChangelogView: View {
    private let entries: [(version: String, notes: [String])] = [
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
