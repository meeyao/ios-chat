import SwiftUI
import WebKit
import DankChatCore

/// Stream information strip with an optional embedded Twitch player.
struct StreamPanelView: View {
    let channel: String
    @EnvironmentObject private var streamStore: StreamStore
    @StateObject private var pipHolder = StreamWebViewHolder(pipEnabled: true)
    @StateObject private var standardHolder = StreamWebViewHolder(pipEnabled: false)
    @State private var showPlayer = false

    private var holder: StreamWebViewHolder {
        streamStore.settings.enablePiP ? pipHolder : standardHolder
    }

    private var stream: StreamInfo? {
        streamStore.streams[channel.lowercased()]
    }

    var body: some View {
        if let stream, streamStore.settings.showStreamInfo {
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let title = stream.title, !title.isEmpty {
                            Text(title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                        Text(stream.summary(showCategory: streamStore.settings.showStreamCategory))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(showPlayer ? "Hide" : "Watch") {
                        showPlayer.toggle()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if showPlayer {
                    StreamWebView(
                        channel: channel,
                        holder: holder,
                        preventReloads: streamStore.settings.preventStreamReloads
                    )
                    .id(streamStore.settings.enablePiP)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct StreamWebView: UIViewRepresentable {
    let channel: String
    @ObservedObject var holder: StreamWebViewHolder
    let preventReloads: Bool

    func makeUIView(context: Context) -> WKWebView {
        holder.webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        holder.load(channel: channel, preventReloads: preventReloads)
    }
}

@MainActor
final class StreamWebViewHolder: ObservableObject {
    let webView: WKWebView
    private var loadedChannel: String?

    init(pipEnabled: Bool = true) {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = pipEnabled

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
    }

    func load(channel: String, preventReloads: Bool) {
        let normalized = channel.lowercased()
        if preventReloads, loadedChannel == normalized {
            return
        }
        loadedChannel = normalized
        guard let url = URL(
            string: "https://player.twitch.tv/?channel=\(normalized)&enableExtensions=true&muted=false&parent=twitch.tv"
        ) else { return }
        webView.load(URLRequest(url: url))
    }
}
