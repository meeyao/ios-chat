import SwiftUI
import DankChatCore

/// View for managing custom commands (create, edit, delete).
///
/// Presented as a sheet from the chat composer via the gear button.
struct CommandManagementView: View {
    @ObservedObject var commandStore: CommandStore
    @Environment(\.dismiss) private var dismiss

    @State private var isAddingNew = false
    @State private var editingCommand: CustomCommand?

    var body: some View {
        NavigationStack {
            List {
                if commandStore.commands.isEmpty {
                    Text("No custom commands yet.\nTap + to create one.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }

                ForEach(commandStore.commands) { command in
                    Button {
                        editingCommand = command
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("/\(command.name)")
                                .font(.headline)
                            Text(command.template)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    commandStore.delete(at: offsets)
                }
            }
            .navigationTitle("Custom Commands")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingNew) {
                CommandEditorView(commandStore: commandStore)
            }
            .sheet(item: $editingCommand) { command in
                CommandEditorView(commandStore: commandStore, editing: command)
            }
        }
    }
}

/// Editor for creating or editing a single custom command.
private struct CommandEditorView: View {
    @ObservedObject var commandStore: CommandStore
    @Environment(\.dismiss) private var dismiss

    let editing: CustomCommand?

    @State private var name: String
    @State private var template: String

    init(commandStore: CommandStore, editing: CustomCommand? = nil) {
        self.commandStore = commandStore
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _template = State(initialValue: editing?.template ?? "")
    }

    private var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTemplate = template.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && !trimmedTemplate.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Command Name") {
                    HStack(spacing: 2) {
                        Text("/")
                            .foregroundStyle(.secondary)
                        TextField("name", text: $name)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                }

                Section {
                    TextField("Template", text: $template, axis: .vertical)
                        .lineLimit(3...6)
                        .autocorrectionDisabled()
                } header: {
                    Text("Template")
                } footer: {
                    Text("Placeholders: {channel}, {user}, {args}")
                        .font(.caption2)
                }
            }
            .navigationTitle(editing == nil ? "New Command" : "Edit Command")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCommand()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func saveCommand() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "")
        let trimmedTemplate = template.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = editing {
            var updated = existing
            updated.name = trimmedName
            updated.template = trimmedTemplate
            commandStore.update(updated)
        } else {
            let command = CustomCommand(name: trimmedName, template: trimmedTemplate)
            commandStore.add(command)
        }
    }
}
