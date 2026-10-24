import SwiftUI

public struct ConnectionStatusView: View {
    @ObservedObject private var store: ConnectionStatusStore

    public init(store: ConnectionStatusStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection")
                .font(.headline)
            Text(statusText)
                .font(.subheadline)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(store.events) { event in
                        Text("\(event.timestamp.formatted(.dateTime.hour().minute().second()))  \(event.message)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
    }

    private var statusText: String {
        switch store.state {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .reconnecting(let attempt):
            return "Reconnecting (attempt \(attempt))"
        case .disconnected(let reason):
            if let reason {
                return "Disconnected: \(reason)"
            }
            return "Disconnected"
        }
    }
}
