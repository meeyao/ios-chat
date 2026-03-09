#if canImport(UIKit)
import SwiftUI
import DankChatCore

struct ChannelStatusIndicator: View {
    let state: IRCConnectionState

    var body: some View {
        Image(systemName: iconName)
            .font(.caption2)
            .foregroundStyle(color)
            .accessibilityLabel(label)
    }

    private var iconName: String {
        switch state {
        case .connected:
            return "checkmark.circle.fill"
        case .connecting:
            return "arrow.triangle.2.circlepath"
        case .reconnecting:
            return "arrow.clockwise.circle.fill"
        case .disconnected:
            return "xmark.circle.fill"
        }
    }

    private var color: Color {
        switch state {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .reconnecting:
            return .orange
        case .disconnected:
            return .red
        }
    }

    private var label: String {
        switch state {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .reconnecting:
            return "Reconnecting"
        case .disconnected:
            return "Disconnected"
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        ChannelStatusIndicator(state: .connected)
        ChannelStatusIndicator(state: .connecting)
        ChannelStatusIndicator(state: .reconnecting(attempt: 2))
        ChannelStatusIndicator(state: .disconnected(reason: nil))
    }
    .padding()
}
#endif
