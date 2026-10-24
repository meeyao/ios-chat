import SafariServices
import SwiftUI

/// Presents a URL in an in-app Safari sheet so the app stays alive while the
/// Twitch device-code polling task is running.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = .systemPurple
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
