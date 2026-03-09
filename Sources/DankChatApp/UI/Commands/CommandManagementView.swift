#if canImport(UIKit)
import SwiftUI
import DankChatCore

struct CommandManagementView: View {
    @ObservedObject var commandStore: CommandStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var newTrigger = ""
    @State private var newAction = ""
    @State private var isShowingAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section("Custom Commands") {
                    if commandStore.commands.isEmpty {
                        Text("No custom commands. Add one below.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(commandStore.commands) { command in
                            VStack(alignment: .leading) {
                                Text(command.trigger)
                                    .font(.headline)
                                Text(command.action)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete(perform: removeCommands)
                    }
                }
            }
            .navigationTitle("Commands")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                NavigationStack {
                    Form {
                        Section("Trigger") {
                            TextField("/hello", text: $newTrigger)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        Section("Action") {
                            TextField("Hello there!", text: $newAction)
                        }
                    }
                    .navigationTitle("Add Command")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isShowingAddSheet = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                addCommand()
                                isShowingAddSheet = false
                            }
                            .disabled(newTrigger.isEmpty || newAction.isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private func addCommand() {
        let trigger = newTrigger.starts(with: "/") ? newTrigger : "/\(newTrigger)"
        let command = Command(id: UUID().uuidString, trigger: trigger, action: newAction)
        commandStore.addCommand(command)
        newTrigger = ""
        newAction = ""
    }

    private func removeCommands(at offsets: IndexSet) {
        for index in offsets {
            let id = commandStore.commands[index].id
            commandStore.removeCommand(id: id)
        }
    }
}
#endif
