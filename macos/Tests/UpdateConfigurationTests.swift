import XCTest
@testable import FukuraMac

final class UpdateConfigurationTests: XCTestCase {
    private let key = Data(repeating: 1, count: 32).base64EncodedString()

    func testHTTPSFeedAndEd25519Key() {
        XCTAssertTrue(UpdateConfiguration.isValid(feed: "https://example.com/appcast.xml", publicKey: key))
    }

    func testMissingConfigurationDoesNotEnableUpdater() {
        XCTAssertFalse(UpdateConfiguration.isValid(feed: nil, publicKey: key))
        XCTAssertFalse(UpdateConfiguration.isValid(feed: "https://example.com/feed", publicKey: nil))
    }

    func testRejectsUnsafeURLs() {
        for feed in ["http://example.com/feed", "file:///tmp/feed", "https:///","https://user:password@example.com/feed"] {
            XCTAssertFalse(UpdateConfiguration.isValid(feed: feed, publicKey: key), feed)
        }
    }

    func testRejectsInvalidKeys() {
        for invalid in ["", "not a key", Data(repeating: 1, count: 31).base64EncodedString()] {
            XCTAssertFalse(UpdateConfiguration.isValid(feed: "https://example.com/feed", publicKey: invalid))
        }
    }
}
