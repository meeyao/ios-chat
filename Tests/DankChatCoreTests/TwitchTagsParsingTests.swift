import XCTest
@testable import DankChatCore

final class TwitchTagsParsingTests: XCTestCase {
    func testEmoteParserReturnsEmptyForNilOrEmptyTag() {
        XCTAssertEqual(TwitchEmoteTagParser.parse(nil, in: "Kappa"), [])
        XCTAssertEqual(TwitchEmoteTagParser.parse("", in: "Kappa"), [])
    }

    func testEmoteParserHandlesMultipleIdsAndRanges() {
        let text = "Kappa Keepo Kappa"
        let tagValue = "25:0-4,12-16/1902:6-10"

        let result = TwitchEmoteTagParser.parse(tagValue, in: text)

        XCTAssertEqual(result, [
            TwitchEmoteOccurrence(emoteId: "25", range: NSRange(location: 0, length: 5)),
            TwitchEmoteOccurrence(emoteId: "25", range: NSRange(location: 12, length: 5)),
            TwitchEmoteOccurrence(emoteId: "1902", range: NSRange(location: 6, length: 5))
        ])
    }

    func testEmoteParserAllowsAdjacentRanges() {
        let text = "KappaKappa"
        let tagValue = "25:0-4,5-9"

        let result = TwitchEmoteTagParser.parse(tagValue, in: text)

        XCTAssertEqual(result, [
            TwitchEmoteOccurrence(emoteId: "25", range: NSRange(location: 0, length: 5)),
            TwitchEmoteOccurrence(emoteId: "25", range: NSRange(location: 5, length: 5))
        ])
    }

    func testEmoteParserAllowsOverlappingRanges() {
        let text = "Kappa"
        let tagValue = "25:0-4/1902:0-4"

        let result = TwitchEmoteTagParser.parse(tagValue, in: text)

        XCTAssertEqual(result, [
            TwitchEmoteOccurrence(emoteId: "25", range: NSRange(location: 0, length: 5)),
            TwitchEmoteOccurrence(emoteId: "1902", range: NSRange(location: 0, length: 5))
        ])
    }

    func testBadgeParserReturnsEmptyForNilOrEmptyTag() {
        XCTAssertEqual(TwitchBadgeTagParser.parse(nil), [])
        XCTAssertEqual(TwitchBadgeTagParser.parse(""), [])
    }

    func testBadgeParserHandlesMultipleBadges() {
        let tagValue = "moderator/1,subscriber/12"

        let result = TwitchBadgeTagParser.parse(tagValue)

        XCTAssertEqual(result, [
            TwitchBadgeTag(id: "moderator", version: "1"),
            TwitchBadgeTag(id: "subscriber", version: "12")
        ])
    }
}
