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
}
