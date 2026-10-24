import SwiftUI
import DankChatCore

/// Settings for notifications, highlight rules, and ignored users.
struct NotificationsSettingsView: View {
    @EnvironmentObject private var notificationService: ChatNotificationService
    @EnvironmentObject private var highlightStore: HighlightStore
    @EnvironmentObject private var ignoreStore: IgnoreStore

    var body: some View {
        List {
            notificationsSection
            highlightsSection
            ignoresSection
        }
        .navigationTitle("Notifications & Highlights")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notificationService.refreshAuthorization()
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Mentions & Highlights", isOn: $notificationService.settings.showNotifications)
            Toggle("Whispers", isOn: $notificationService.settings.showWhisperNotifications)
                .disabled(!notificationService.settings.showNotifications)

            Picker("Mention format", selection: $notificationService.settings.mentionFormat) {
                ForEach(MentionFormat.allCases) { format in
                    Text(format.template).tag(format)
                }
            }

            if notificationService.isAuthorized {
                Label("Notifications allowed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.footnote)
            } else {
                Button("Allow Notifications") {
                    Task { await notificationService.requestAuthorization() }
                }
            }
        }
    }

    private var highlightsSection: some View {
        Section {
            ForEach(highlightStore.rules) { rule in
                NavigationLink {
                    HighlightRuleEditor(rule: highlightBinding(rule))
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rule.pattern.isEmpty ? "New highlight" : rule.pattern)
                            .lineLimit(1)
                        Text("\(rule.kind.displayName)\(rule.createNotification ? " · notify" : "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        highlightStore.remove(id: rule.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            Button {
                highlightStore.addRule()
            } label: {
                Label("Add Highlight", systemImage: "plus")
            }
        } header: {
            Text("Highlights")
        } footer: {
            Text("Message highlights match whole words unless you use a regular expression. Custom colors override the default highlight color.")
        }
    }

    private var ignoresSection: some View {
        Section {
            ForEach(ignoreStore.rules) { rule in
                NavigationLink {
                    IgnoreRuleEditor(rule: ignoreBinding(rule))
                } label: {
                    Text(rule.pattern.isEmpty ? "New ignored user" : rule.pattern)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        ignoreStore.remove(id: rule.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            Button {
                ignoreStore.addRule()
            } label: {
                Label("Add Ignored User", systemImage: "plus")
            }
        } header: {
            Text("Ignored Users")
        } footer: {
            Text("Messages from ignored users are hidden from every timeline and do not notify.")
        }
    }

    private func highlightBinding(_ rule: HighlightRule) -> Binding<HighlightRule> {
        Binding(
            get: { highlightStore.rules.first(where: { $0.id == rule.id }) ?? rule },
            set: { highlightStore.update($0) }
        )
    }

    private func ignoreBinding(_ rule: IgnoreRule) -> Binding<IgnoreRule> {
        Binding(
            get: { ignoreStore.rules.first(where: { $0.id == rule.id }) ?? rule },
            set: { ignoreStore.update($0) }
        )
    }
}

private struct HighlightRuleEditor: View {
    @Binding var rule: HighlightRule

    private let colors: [String?] = [nil, "#FF8800", "#FF3B30", "#FFCC00", "#34C759", "#0A84FF", "#AF52DE", "#FF2D55"]

    var body: some View {
        Form {
            Section {
                TextField("Pattern", text: $rule.pattern)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Picker("Matches", selection: $rule.kind) {
                    ForEach(HighlightKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }

                Toggle("Enabled", isOn: $rule.isEnabled)
            }

            if rule.kind == .message {
                Section {
                    Toggle("Regular expression", isOn: $rule.isRegex)
                    Toggle("Case sensitive", isOn: $rule.isCaseSensitive)
                } footer: {
                    Text("Regular expressions are matched against the raw message text.")
                }
            }

            Section {
                Toggle("Create notification", isOn: $rule.createNotification)
            }

            Section("Color") {
                Picker("Highlight color", selection: $rule.colorHex) {
                    Text("Default").tag(String?.none)
                    ForEach(colors.compactMap { $0 }, id: \.self) { hex in
                        Text(colorName(hex)).tag(String?.some(hex))
                    }
                }
            }
        }
        .navigationTitle("Highlight")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func colorName(_ hex: String) -> String {
        switch hex {
        case "#FF8800": return "Orange"
        case "#FF3B30": return "Red"
        case "#FFCC00": return "Yellow"
        case "#34C759": return "Green"
        case "#0A84FF": return "Blue"
        case "#AF52DE": return "Purple"
        case "#FF2D55": return "Pink"
        default: return hex
        }
    }
}

private struct IgnoreRuleEditor: View {
    @Binding var rule: IgnoreRule

    var body: some View {
        Form {
            Section {
                TextField("Username", text: $rule.pattern)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Toggle("Enabled", isOn: $rule.isEnabled)
                Toggle("Regular expression", isOn: $rule.isRegex)
            } footer: {
                Text("Matches the author's login or display name, case-insensitively.")
            }
        }
        .navigationTitle("Ignored User")
        .navigationBarTitleDisplayMode(.inline)
    }
}
