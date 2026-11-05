import XCTest

final class RoutesETAUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testDrillIntoACommuteAndBack() throws {
    let app = XCUIApplication()
    app.launch()

    let commute = app.staticTexts["Work to Home"]
    XCTAssertTrue(commute.waitForExistence(timeout: 10))
    commute.tap()

    XCTAssertTrue(app.buttons["Show ETAs"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["City"].exists)

    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(app.navigationBars["Commutes"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testDeleteAsksForConfirmation() throws {
    let app = XCUIApplication()
    app.launch()

    let commute = app.staticTexts["Home to Work"]
    XCTAssertTrue(commute.waitForExistence(timeout: 10))
    commute.swipeLeft()
    app.buttons["Delete"].tap()

    // Cancelling keeps the commute.
    XCTAssertTrue(app.buttons["Delete Commute"].waitForExistence(timeout: 5))
    app.buttons["Cancel"].tap()
    XCTAssertTrue(commute.waitForExistence(timeout: 5))

    // Confirming removes it.
    commute.swipeLeft()
    app.buttons["Delete"].tap()
    app.buttons["Delete Commute"].tap()
    XCTAssertTrue(commute.waitForNonExistence(timeout: 5))
  }

  @MainActor
  func testChangeDestinationAndRenameFromDetail() throws {
    let app = XCUIApplication()
    app.launch()

    app.staticTexts["Work to Home"].tap()

    // Pick a different destination.
    app.buttons["endpoint-To"].tap()
    let place = app.buttons["Polanco"]
    XCTAssertTrue(place.waitForExistence(timeout: 5))
    place.tap()
    let row = app.buttons["endpoint-To"]
    let updated = expectation(
      for: NSPredicate(format: "label CONTAINS 'Polanco'"), evaluatedWith: row)
    wait(for: [updated], timeout: 5)

    // Rename via the menu.
    app.buttons["More"].tap()
    app.buttons["Rename"].tap()
    let field = app.alerts.textFields["Name"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.clearAndType("Evening")
    app.alerts.buttons["Rename"].tap()
    XCTAssertTrue(app.navigationBars["Evening"].waitForExistence(timeout: 5))
  }
}

extension XCUIElement {
  func clearAndType(_ text: String) {
    tap()
    let current = (value as? String) ?? ""
    typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + text)
  }
}
