import SwiftUI
import DankChatCore

struct ChatSettingsView: View {
    @ObservedObject var settings: ChatSettings

    var body: some View {
        GroupBox("Chat Settings") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Show Timestamps", isOn: $settings.showTimestamps)
                Toggle("Show Usernames", isOn: $settings.showUsernames)
                Toggle("Animate Emotes", isOn: $settings.allowAnimatedEmotes)

                Stepper(value: $settings.scrollbackLimit, in: 100...2000, step: 50) {
                    HStack {
                        Text("Scrollback Limit")
                        Spacer()
                        Text("\(settings.scrollbackLimit)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    let settings = ChatSettings()
    return ChatSettingsView(settings: settings)
        .padding()
}
