import XCTest

/// The location permission on Home: the explanation shown before the system prompt, "Not now",
/// and the row in the commutes list that is the way back in.
@MainActor
final class HomeLocationUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  /// `-mock-location-prompt`: the permission is still undecided, and saying yes puts the user at
  /// `place`.
  private func launchUndecided(at place: String = "work") -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-mock-services", "-mock-location", place, "-mock-location-prompt"]
    app.launch()
    return app
  }

  private func chip(_ route: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any)["eta-\(route)"]
  }

  func testTheExplanationComesBeforeAnyNumbers() throws {
    let app = launchUndecided()
    XCTAssertTrue(app.buttons["location-continue"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["location-not-now"].exists)
    XCTAssertTrue(app.staticTexts["Show the commute that starts where you are"].exists)
    XCTAssertFalse(chip("City", in: app).exists)
  }

  func testContinueAsksAndThenOpensOnTheCommuteWhereYouAre() throws {
    let app = launchUndecided(at: "work")
    app.buttons["location-continue"].tap()
    XCTAssertTrue(chip("Mordor", in: app).waitForExistence(timeout: 10))
    XCTAssertEqual(app.staticTexts["home-reason"].label, "Near Work")
    XCTAssertFalse(app.buttons["location-continue"].exists)
  }

  func testNotNowShowsTheFirstCommuteAndDoesNotAskAgain() throws {
    let app = launchUndecided(at: "home")
    app.buttons["location-not-now"].tap()
    // Without location it is the first commute ("Work to Home"), not the one at home.
    XCTAssertTrue(chip("Mordor", in: app).waitForExistence(timeout: 10))

    // Leaving and coming back must not bring the explanation back.
    app.buttons["Edit"].tap()
    XCTAssertTrue(app.navigationBars["Commutes"].waitForExistence(timeout: 5))
    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(chip("Mordor", in: app).waitForExistence(timeout: 10))
    XCTAssertFalse(app.buttons["location-continue"].exists)
  }

  func testTheCommutesListIsTheWayBackInAfterNotNow() throws {
    let app = launchUndecided(at: "home")
    app.buttons["location-not-now"].tap()
    XCTAssertTrue(chip("Mordor", in: app).waitForExistence(timeout: 10))

    app.buttons["Edit"].tap()
    let row = app.buttons["location-setting-action"]
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    XCTAssertTrue(row.label.contains("Use my location to pick the commute"))
    row.tap()
    let working = app.descendants(matching: .any)["location-setting"]
    XCTAssertTrue(
      NSPredicate(format: "label CONTAINS 'Using your location'")
        .evaluate(with: working.waitForExistence(timeout: 5) ? working : nil))

    // Home now chooses by location: at home, that is "Home to Work", which has no Mordor.
    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(chip("Mordor", in: app).waitForNonExistence(timeout: 10))
    XCTAssertEqual(app.staticTexts["home-reason"].label, "Near Home")
  }

  func testARefusalIsExplainedInTheListWithAWayToSettings() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-mock-services"]  // location denied
    app.launch()
    XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 10))
    app.buttons["Edit"].tap()

    let row = app.buttons["location-setting-action"]
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    XCTAssertTrue(row.label.contains("Location is off"))
  }
}
