//
//  EntryFlowUITests.swift
//  Folk's DBUITests
//
//  Smoke test for creating a collection, adding a key and editing its value.
//

import XCTest

final class EntryFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAddAndEditEntry() throws {
        let app = XCUIApplication()
        app.launch()

        let collectionName = "UITest \(UUID().uuidString.prefix(6))"
        app.buttons["Add New Collection"].tap()
        let nameField = app.textFields["Collection Name"]
        nameField.tap()
        nameField.typeText(collectionName)
        app.buttons["Save"].tap()

        app.staticTexts[collectionName].firstMatch.tap()

        // Add a key
        app.buttons["Add Entry"].tap()
        let keyField = app.textFields["Key"]
        keyField.tap()
        keyField.typeText("theme")
        let valueField = app.textFields["entryTextValue"]
        valueField.tap()
        valueField.typeText("dark")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["theme"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["dark"].exists)

        // Edit its value
        app.staticTexts["theme"].tap()
        let editField = app.textFields["entryTextValue"]
        XCTAssertTrue(editField.waitForExistence(timeout: 5))
        editField.doubleTap() // selects the word, so typing replaces it
        editField.typeText("light")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["light"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["dark"].exists)
    }
}
