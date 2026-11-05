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
}
