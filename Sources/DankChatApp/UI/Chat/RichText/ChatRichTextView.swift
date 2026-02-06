import SwiftUI
import UIKit
import SDWebImage
import DankChatCore

struct ChatRichTextView: UIViewRepresentable {
    let message: ChatMessage
    @ObservedObject var settings: ChatSettings
    @ObservedObject var emoteStore: EmoteStore
    @Environment(\.openURL) private var openURL

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.dataDetectorTypes = [.link]
        textView.delegate = context.coordinator
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let font = context.coordinator.messageFont(isAction: message.isAction)
        let builder = ChatRichTextBuilder(emoteStore: emoteStore)
        let configuration = ChatRichTextBuilder.Configuration(
            font: font,
            allowAnimatedEmotes: settings.allowAnimatedEmotes
        )
        let attributed = builder.build(message: message, configuration: configuration)

        if textView.attributedText != attributed {
            textView.attributedText = attributed
        }

        context.coordinator.loadEmotes(in: textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(openURL: openURL)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let openURL: OpenURLAction

        init(openURL: OpenURLAction) {
            self.openURL = openURL
        }

        func textView(
            _ textView: UITextView,
            shouldInteractWith url: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            openURL(url)
            return false
        }

        func messageFont(isAction: Bool) -> UIFont {
            let baseFont = UIFont.preferredFont(forTextStyle: .subheadline)
            guard isAction else { return baseFont }
            guard let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitItalic) else {
                return baseFont
            }
            return UIFont(descriptor: descriptor, size: baseFont.pointSize)
        }

        func loadEmotes(in textView: UITextView) {
            let attributedText = textView.attributedText
            let fullRange = NSRange(location: 0, length: attributedText.length)
            attributedText.enumerateAttribute(.attachment, in: fullRange) { value, range, _ in
                guard let attachment = value as? ChatEmoteAttachment else { return }
                if attachment.image != nil { return }

                SDWebImageManager.shared.loadImage(
                    with: attachment.imageURL,
                    options: [.highPriority],
                    progress: nil
                ) { image, _, _, _, _, _ in
                    guard let image else { return }
                    DispatchQueue.main.async {
                        attachment.image = image
                        textView.layoutManager.invalidateLayout(
                            forCharacterRange: range,
                            actualCharacterRange: nil
                        )
                        textView.layoutManager.invalidateDisplay(forCharacterRange: range)
                    }
                }
            }
        }
    }
}
