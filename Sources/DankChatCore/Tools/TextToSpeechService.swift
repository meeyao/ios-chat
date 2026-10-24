import AVFoundation
import Combine
import Foundation

/// Speaks chat messages using AVSpeechSynthesizer according to the tools settings.
@MainActor
public final class TextToSpeechService: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var lastSpeaker: String?

    public init() {}

    public func speak(_ message: ChatMessage, settings: ToolsSettings) {
        guard settings.ttsEnabled else { return }

        let login = message.user.login.lowercased()
        let displayName = message.user.displayName.lowercased()
        let ignored = settings.ttsUserIgnoreList.contains { ignoredUser in
            let needle = ignoredUser.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !needle.isEmpty else { return false }
            return needle.caseInsensitiveCompare(login) == .orderedSame
                || needle.caseInsensitiveCompare(displayName) == .orderedSame
        }
        guard !ignored else { return }

        var text = message.text
        if settings.ttsIgnoreEmotes {
            text = Self.filterEmoteRanges(text, ranges: message.twitchEmotes.map(\.range))
            text = Self.filterUnicodeSymbols(text)
        }
        if settings.ttsIgnoreURLs {
            text = Self.filterURLs(text)
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let spokenText: String
        if settings.ttsMessageFormat == .userAndMessage, lastSpeaker != login {
            spokenText = "\(message.user.displayName) said \(text)"
        } else {
            spokenText = text
        }
        lastSpeaker = login

        if settings.ttsPlayMode == .newest, synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: spokenText)
        if settings.ttsForceEnglish {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        synthesizer.speak(utterance)
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        lastSpeaker = nil
    }

    private static func filterEmoteRanges(_ text: String, ranges: [NSRange]) -> String {
        let result = NSMutableString(string: text)
        for range in ranges.sorted(by: { $0.location > $1.location }) {
            guard range.location != NSNotFound,
                  NSMaxRange(range) <= result.length
            else { continue }
            result.replaceCharacters(in: range, with: "")
        }
        return result as String
    }

    private static func filterUnicodeSymbols(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\p{So}|\p{Sc}|\p{Sm}|\p{Cn}"#) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    private static func filterURLs(_ text: String) -> String {
        let pattern = #"[(http(s)?):\/\/(www\.)?a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }
}
