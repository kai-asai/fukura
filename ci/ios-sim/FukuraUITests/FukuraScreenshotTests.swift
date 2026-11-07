import XCTest

final class FukuraScreenshotTests: XCTestCase {
    private var shotDir: URL {
        URL(fileURLWithPath: "/tmp/fukura-screenshots", isDirectory: true)
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
    }

    func testListAndEditor() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["fukura"].waitForExistence(timeout: 15))
        save(app, name: "01-list")

        let plus = app.buttons["plus"]
        let add = app.buttons["Add"]
        if plus.waitForExistence(timeout: 2) {
            plus.tap()
        } else if add.exists {
            add.tap()
        } else {
            XCTAssertGreaterThan(app.buttons.count, 0)
            app.buttons.element(boundBy: app.buttons.count - 1).tap()
        }
        XCTAssertTrue(app.staticTexts["辞書を編集"].waitForExistence(timeout: 8))
        save(app, name: "02-editor-new")

        if app.buttons["キャンセル"].waitForExistence(timeout: 2) {
            app.buttons["キャンセル"].tap()
        }
        let mail = app.staticTexts[";mail"]
        if mail.waitForExistence(timeout: 4) {
            mail.tap()
            _ = app.staticTexts["辞書を編集"].waitForExistence(timeout: 5)
            save(app, name: "03-editor-mail")
        }
    }

    func testEditorFieldShowsAKeyboard() throws {
        let app = XCUIApplication()
        app.launch()
        let plus = app.buttons["plus"]
        if plus.waitForExistence(timeout: 4) {
            plus.tap()
        } else if app.buttons["Add"].exists {
            app.buttons["Add"].tap()
        } else {
            throw XCTSkip("Could not open the editor, so the keyboard was not captured.")
        }
        XCTAssertTrue(app.staticTexts["辞書を編集"].waitForExistence(timeout: 8))
        let field = app.textFields.firstMatch
        if field.waitForExistence(timeout: 3) {
            field.tap()
        } else if app.textViews.firstMatch.waitForExistence(timeout: 2) {
            app.textViews.firstMatch.tap()
        }
        sleep(1)
        save(app, name: "04-editor-with-keyboard")
        let note = """
        04-editor-with-keyboard is the editor after focusing a text field.
        The system keyboard appears until Fukura Keyboard is added in Settings and selected.
        This harness does not change the shipped keyboard extension.
        """
        try note.write(to: shotDir.appendingPathComponent("KEYBOARD.txt"), atomically: true, encoding: .utf8)
    }

    private func save(_ app: XCUIApplication, name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try? shot.pngRepresentation.write(to: shotDir.appendingPathComponent("\(name).png"))
    }
}
