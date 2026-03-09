#if canImport(UIKit)
import SwiftUI
import DankChatCore

struct ConnectionStatusView: View {
    @ObservedObject var store: ConnectionStatusStore

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(store.status.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var color: Color {
        switch store.status {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .red
        }
    }
}
#endif
