import XCTest
@testable import DankChatCore

final class IRCMessageParserTests: XCTestCase {
    func testParsesTagsPrefixAndTrailingParams() {
        let line = "@badge-info=;display-name=Cool\\sUser;emotes=;id=abc :user!u@h PRIVMSG #chan :hello there"
        let message = IRCMessageParser.parse(line: line)

        XCTAssertNotNil(message)
        XCTAssertEqual(message?.tags["display-name"] ?? nil, "Cool User")
        XCTAssertEqual(message?.prefix, "user!u@h")
        XCTAssertEqual(message?.command, "PRIVMSG")
        XCTAssertEqual(message?.params, ["#chan", "hello there"])
    }

    func testParsesPrefixNotice() {
        let line = ":tmi.twitch.tv NOTICE #chan :This is a notice"
        let message = IRCMessageParser.parse(line: line)

        XCTAssertNotNil(message)
        XCTAssertEqual(message?.prefix, "tmi.twitch.tv")
        XCTAssertEqual(message?.command, "NOTICE")
        XCTAssertEqual(message?.params, ["#chan", "This is a notice"])
    }

    func testParsesPingTrailingParam() {
        let line = "PING :tmi.twitch.tv"
        let message = IRCMessageParser.parse(line: line)

        XCTAssertNotNil(message)
        XCTAssertEqual(message?.command, "PING")
        XCTAssertEqual(message?.params, ["tmi.twitch.tv"])
    }
}
