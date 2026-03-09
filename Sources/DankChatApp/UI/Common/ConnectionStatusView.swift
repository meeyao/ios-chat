import SwiftUI
import DankChatCore

struct ConnectionStatusView: View {
    @ObservedObject var store: ConnectionStatusStore

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusText: String {
        // This is a stub, in a real app we'd map ConnectionStatusStore.state
        return "Connected"
    }

    private var statusColor: Color {
        return .green
    }
}
