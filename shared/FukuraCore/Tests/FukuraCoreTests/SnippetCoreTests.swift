import XCTest
@testable import FukuraCore

final class SnippetCoreTests: XCTestCase {
    func testExampleSkipsDisabledSnippet() throws {
        let file = try SnippetValidator.decode(Data(SnippetValidator.exampleJSON.utf8))
        XCTAssertEqual(file.version, 1)
        XCTAssertTrue(file.snippets.contains { $0.trigger == ";mail" && $0.enabled != false })
        XCTAssertEqual(file.snippets.first { $0.trigger == ";addr" }?.enabled, false)
    }

    func testOmittedEnabledStaysAvailable() throws {
        let json = #"{"version":1,"snippets":[{"id":"mail","trigger":";mail","body":"a@example.com"}]}"#
        let file = try SnippetValidator.decode(Data(json.utf8))
        XCTAssertNil(file.snippets[0].enabled)
        let matcher = SnippetMatcher(snippets: file.snippets)
        XCTAssertEqual(matcher.push(";mail")?.id, "mail")
    }

    func testInvalidJsonVersionDuplicatesAndTypes() {
        XCTAssertThrowsError(try SnippetValidator.decode(Data("{ broken".utf8))) { error in
            XCTAssertEqual(error as? SnippetValidationError, .invalidSnippet("snippets.json のJSONが不正です。"))
        }
        XCTAssertThrowsError(try SnippetValidator.decode(Data(#"{"version":2,"snippets":[]}"#.utf8))) { error in
            XCTAssertEqual(error as? SnippetValidationError, .unsupportedVersion)
        }
        XCTAssertThrowsError(try SnippetValidator.decode(Data(#"{"version":1,"snippets":[{"id":"x","trigger":";x"}]}"#.utf8)))
        XCTAssertThrowsError(try SnippetValidator.decode(Data(#"{"version":1,"snippets":[{"id":"a","trigger":";x","body":"A"},{"id":"b","trigger":";x","body":"B"}]}"#.utf8))) { error in
            XCTAssertEqual(error as? SnippetValidationError, .duplicateTrigger(";x"))
        }
        XCTAssertThrowsError(try SnippetValidator.decode(Data(#"{"version":1,"snippets":[{"id":"a","trigger":";x","body":"A","enabled":"yes"}]}"#.utf8)))
    }

    func testLimits() {
        let snippets = (0..<501).map { index in
            #"{"id":"s\#(index)","trigger":";s\#(index)","body":"body"}"#
        }.joined(separator: ",")
        XCTAssertThrowsError(try SnippetValidator.decode(Data(#"{"version":1,"snippets":[\#(snippets)]}"#.utf8)))
        XCTAssertThrowsError(try SnippetValidator.decode(Data(#"{"version":1,"snippets":[{"id":"long","trigger":";\#(String(repeating: "x", count: 64))","body":"body"}]}"#.utf8)))
        XCTAssertThrowsError(try SnippetValidator.decode(Data(#"{"version":1,"snippets":[{"id":"body","trigger":";body","body":"\#(String(repeating: "x", count: 8001))}"}]}"#.utf8)))
        XCTAssertThrowsError(try SnippetValidator.decode(Data(repeating: 0x78, count: Int(SnippetValidator.maxJSONBytes) + 1))) { error in
            XCTAssertEqual(error as? SnippetValidationError, .fileTooLarge(SnippetValidator.maxJSONBytes))
        }
    }

    func testLongerTriggerAndBackspace() {
        let matcher = SnippetMatcher(snippets: [
            Snippet(id: "short", trigger: ";t", body: "short", enabled: true),
            Snippet(id: "long", trigger: ";today", body: "long", enabled: true),
            Snippet(id: "address", trigger: ";addr", body: "hidden", enabled: false)
        ])
        XCTAssertEqual(matcher.push(";t")?.id, "short")
        XCTAssertEqual(matcher.push("oday")?.id, "long")
        XCTAssertNil(matcher.backspace())
        XCTAssertEqual(matcher.push("y")?.id, "long")
        matcher.reset()
        XCTAssertNil(matcher.push(";addr"))
    }

    func testBackspaceRemovesOneCharacter() {
        let matcher = SnippetMatcher(snippets: [
            Snippet(id: "mail", trigger: ";mail", body: "a@example.com", enabled: true)
        ])
        XCTAssertNil(matcher.push(";mai"))
        XCTAssertNil(matcher.backspace())
        XCTAssertNil(matcher.push("i"))
        XCTAssertEqual(matcher.push("l")?.id, "mail")
    }

    func testRoundTripKeepsMultilineBodyAndDisabledSnippet() throws {
        let file = SnippetFile(
            version: 1,
            updatedAt: "2026-11-07T00:00:00Z",
            snippets: [
                Snippet(id: "lines", trigger: ";lines", body: "1行目\n2行目", enabled: true, tags: ["note"]),
                Snippet(id: "address", trigger: ";addr", body: "非公開", enabled: false)
            ]
        )
        let decoded = try SnippetValidator.decode(try SnippetValidator.encode(file))
        XCTAssertEqual(decoded, file)
        XCTAssertEqual(decoded.snippets[0].body.split(separator: "\n").count, 2)
    }

    func testEmptyMatcherNeverMatches() {
        let matcher = SnippetMatcher(snippets: [])
        XCTAssertFalse(matcher.hasSnippets)
        XCTAssertNil(matcher.push(";mail"))
        XCTAssertNil(matcher.backspace())
    }
}
