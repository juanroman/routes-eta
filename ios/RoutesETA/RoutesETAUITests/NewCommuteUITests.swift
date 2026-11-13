import XCTest

/// The form behind "Add Commute": a name and both places, then it opens the new commute.
@MainActor
final class NewCommuteUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  private func openForm() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-mock-services"]
    app.launch()
    app.buttons["Add Commute"].tap()
    XCTAssertTrue(app.textFields["commute-name"].waitForExistence(timeout: 10))
    return app
  }

  private func pick(
    _ place: String, searching text: String, for endpoint: String, in app: XCUIApplication
  ) {
    app.buttons["endpoint-\(endpoint)"].tap()
    let search = app.searchFields.firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    search.tap()
    search.typeText(text)
    let result = app.buttons["place-\(place)"]
    XCTAssertTrue(result.waitForExistence(timeout: 5))
    result.tap()
  }

  func testAddStaysDisabledUntilTheNameAndBothPlacesAreSet() throws {
    let app = openForm()
    let add = app.buttons["add-commute-confirm"]
    XCTAssertFalse(add.isEnabled)

    app.textFields["commute-name"].tap()
    app.textFields["commute-name"].typeText("Gym")
    XCTAssertFalse(add.isEnabled)

    pick("Polanco", searching: "Pola", for: "From", in: app)
    XCTAssertFalse(add.isEnabled)

    pick("Satélite", searching: "Sat", for: "To", in: app)
    XCTAssertTrue(add.waitForExistence(timeout: 5))
    XCTAssertTrue(add.isEnabled)
  }

  func testCreatingACommuteOpensItReadyForItsFirstRoute() throws {
    let app = openForm()
    app.textFields["commute-name"].tap()
    app.textFields["commute-name"].typeText("Gym")
    pick("Polanco", searching: "Pola", for: "From", in: app)
    pick("Satélite", searching: "Sat", for: "To", in: app)
    app.buttons["add-commute-confirm"].tap()

    // It opens the new commute, whose places are already set and need no Edit.
    XCTAssertTrue(app.buttons["add-route"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["Add your first route"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["endpoint-From"].exists)
  }

  func testCancellingTheFormAddsNothing() throws {
    let app = openForm()
    app.textFields["commute-name"].tap()
    app.textFields["commute-name"].typeText("Gym")
    app.buttons["Cancel"].tap()

    XCTAssertTrue(app.staticTexts["Work to Home"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["Gym"].exists)
  }
}
