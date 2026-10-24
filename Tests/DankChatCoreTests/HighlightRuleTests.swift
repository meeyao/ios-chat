import XCTest
import DankChatCore

final class HighlightRuleTests: XCTestCase {
    func testUsernameMatchesLoginOrDisplayNameCaseInsensitively() {
        let message = makeMessage(login: "SomeUser", displayName: "SomeUser")
        let rule = HighlightRule(kind: .username, pattern: "someuser")
        XCTAssertTrue(rule.matches(message))
    }

    func testMessageHighlightMatchesWholeWords() {
        let message = makeMessage(text: "hello world")
        XCTAssertTrue(HighlightRule(kind: .message, pattern: "world").matches(message))
        XCTAssertFalse(HighlightRule(kind: .message, pattern: "wor").matches(message))
    }

    func testMessageHighlightSupportsRegex() {
        let message = makeMessage(text: "deploy failed for build-42")
        let rule = HighlightRule(kind: .message, pattern: #"build-\d+"#, isRegex: true)
        XCTAssertTrue(rule.matches(message))
    }

    func testBadgeHighlightMatchesIdAndVersion() {
        let message = makeMessage(badges: [TwitchBadgeTag(id: "moderator", version: "1")])
        XCTAssertTrue(HighlightRule(kind: .badge, pattern: "moderator").matches(message))
        XCTAssertTrue(HighlightRule(kind: .badge, pattern: "moderator/1").matches(message))
        XCTAssertFalse(HighlightRule(kind: .badge, pattern: "vip").matches(message))
    }

    @MainActor
    func testHighlightStorePersistsRules() {
        let suite = "highlight-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = HighlightStore(defaults: defaults)
        let rule = store.addRule(kind: .message)
        var updated = rule
        updated.pattern = "deploy"
        store.update(updated)

        let reloaded = HighlightStore(defaults: defaults)
        XCTAssertEqual(reloaded.rules.first?.pattern, "deploy")
    }

    private func makeMessage(
        text: String = "hello",
        login: String = "viewer",
        displayName: String = "Viewer",
        badges: [TwitchBadgeTag] = []
    ) -> ChatMessage {
        ChatMessage(
            id: UUID().uuidString,
            user: ChatUser(displayName: displayName, login: login),
            text: text,
            timestamp: Date(),
            receivedAt: Date(),
            channel: "dankchat",
            badgeTags: badges
        )
    }
}

final class IgnoreRuleTests: XCTestCase {
    func testIgnoreMatchesLoginCaseInsensitively() {
        let rule = IgnoreRule(pattern: "Troll")
        XCTAssertTrue(rule.matches(login: "troll", displayName: "TROLL"))
        XCTAssertFalse(rule.matches(login: "friend", displayName: "Friend"))
    }

    func testIgnoreSupportsRegex() {
        let rule = IgnoreRule(pattern: #"bot_\d+"#, isRegex: true)
        XCTAssertTrue(rule.matches(login: "bot_42", displayName: "bot_42"))
        XCTAssertFalse(rule.matches(login: "bot", displayName: "bot"))
    }

    @MainActor
    func testIgnoreStorePersistsRules() {
        let suite = "ignore-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = IgnoreStore(defaults: defaults)
        let rule = store.addRule()
        var updated = rule
        updated.pattern = "spammer"
        store.update(updated)

        let reloaded = IgnoreStore(defaults: defaults)
        XCTAssertEqual(reloaded.rules.first?.pattern, "spammer")
    }
}
