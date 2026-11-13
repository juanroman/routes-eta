import XCTest

/// The Home view: which commute it opens on, switching, refreshing, and what it shows beside
/// the numbers. The sample data has "Work to Home" (routes City and Mordor) and "Home to Work"
/// (route City), so which routes are on screen says which commute it is.
@MainActor
final class HomeUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  private func launch(_ extra: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-mock-services"] + extra
    app.launch()
    return app
  }

  private func chip(_ route: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any)["eta-\(route)"]
  }

  private func segment(_ commute: String, in app: XCUIApplication) -> XCUIElement {
    app.segmentedControls["home-selector"].buttons[commute]
  }

  // MARK: - Which commute

  func testOpensOnTheCommuteThatStartsWhereYouAre() throws {
    let app = launch(["-mock-location", "work"])
    XCTAssertTrue(chip("Mordor", in: app).waitForExistence(timeout: 10))
    XCTAssertTrue(chip("City", in: app).exists)
    XCTAssertTrue(segment("Work to Home", in: app).isSelected)
    XCTAssertEqual(app.staticTexts["home-reason"].label, "Near Work")
  }

  func testOpensOnTheOtherCommuteWhenYouAreAtItsOrigin() throws {
    let app = launch(["-mock-location", "home"])
    XCTAssertTrue(chip("City", in: app).waitForExistence(timeout: 10))
    XCTAssertFalse(chip("Mordor", in: app).exists)
    XCTAssertTrue(segment("Home to Work", in: app).isSelected)
    XCTAssertEqual(app.staticTexts["home-reason"].label, "Near Home")
  }

  func testNothingNearOpensOnTheFirstCommuteWithoutAReason() throws {
    let app = launch(["-mock-location", "far"])
    XCTAssertTrue(chip("Mordor", in: app).waitForExistence(timeout: 10))
    XCTAssertTrue(segment("Work to Home", in: app).isSelected)
    XCTAssertFalse(app.staticTexts["home-reason"].exists)
  }

  func testWithoutLocationItOpensOnTheFirstCommuteAndNeverAsks() throws {
    let app = launch()
    XCTAssertTrue(chip("Mordor", in: app).waitForExistence(timeout: 10))
    XCTAssertFalse(app.buttons["location-continue"].exists)
  }

  // MARK: - Choosing by hand

  func testPickingAnotherCommuteShowsItsOwnRoutes() throws {
    let app = launch(["-mock-location", "work"])
    XCTAssertTrue(chip("Mordor", in: app).waitForExistence(timeout: 10))

    segment("Home to Work", in: app).tap()
    XCTAssertTrue(chip("Mordor", in: app).waitForNonExistence(timeout: 10))
    XCTAssertTrue(chip("City", in: app).exists)
    XCTAssertTrue(segment("Home to Work", in: app).isSelected)
    // Chosen by hand, not by where you are, so there is no reason to give.
    XCTAssertFalse(app.staticTexts["home-reason"].exists)
  }

  // MARK: - The numbers

  func testEachChipReadsAsOneThingWithMinutesAndExactlyOneIsFastest() throws {
    let app = launch(["-mock-location", "work"])
    let city = chip("City", in: app)
    XCTAssertTrue(city.waitForExistence(timeout: 10))
    let mordor = chip("Mordor", in: app)
    XCTAssertTrue(city.label.contains("City") && city.label.contains("min"))
    XCTAssertNotEqual(city.label.contains("Fastest"), mordor.label.contains("Fastest"))
  }

  func testTheNumbersCarryTheirAgeAndGoogleSAttribution() throws {
    let app = launch(["-mock-location", "work"])
    XCTAssertTrue(chip("City", in: app).waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["home-updated"].label.hasPrefix("Updated "))
    XCTAssertEqual(app.staticTexts["google-attribution"].label, "Google Maps")
  }

  func testPullingDownFetchesFreshNumbers() throws {
    let app = launch(["-mock-location", "work"])
    XCTAssertTrue(chip("City", in: app).waitForExistence(timeout: 10))
    let updated = app.staticTexts["home-updated"]
    sleep(5)
    let before = ageInSeconds(updated.label)
    XCTAssertGreaterThanOrEqual(before, 5)

    // Two chips don't fill the screen, so this also checks that a short list can still be pulled.
    let start = chip("City", in: app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    start.press(
      forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 450)),
      withVelocity: .slow, thenHoldForDuration: 1)

    // The age starts over (the chips dim while the request is in flight, then come back).
    let startedOver = NSPredicate { _, _ in self.ageInSeconds(updated.label) < before }
    expectation(for: startedOver, evaluatedWith: nil)
    waitForExpectations(timeout: 15)
    XCTAssertTrue(chip("City", in: app).exists)
  }

  /// "Updated just now" is 0; "Updated 12 seconds ago" is 12; anything older than a minute is
  /// large enough for these tests.
  private func ageInSeconds(_ label: String) -> Int {
    if label.contains("just now") { return 0 }
    guard label.contains("second") else { return 3_600 }
    return label.split(separator: " ").compactMap { Int($0) }.first ?? 3_600
  }

  // MARK: - Editing

  func testEditOpensTheCommutesListAndBackReturnsToHome() throws {
    let app = launch(["-mock-location", "work"])
    XCTAssertTrue(chip("City", in: app).waitForExistence(timeout: 10))

    app.buttons["Edit"].tap()
    XCTAssertTrue(app.navigationBars["Commutes"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Work to Home"].exists)

    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(app.navigationBars["ETAs"].waitForExistence(timeout: 5))
    XCTAssertTrue(chip("City", in: app).waitForExistence(timeout: 10))
  }

  // MARK: - Large type

  func testAtAccessibilitySizesTheSelectorBecomesAMenu() throws {
    let app = launch([
      "-mock-location", "work",
      "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
    ])
    XCTAssertTrue(app.buttons["home-selector"].waitForExistence(timeout: 10))
    XCTAssertFalse(app.segmentedControls["home-selector"].exists)
    XCTAssertTrue(chip("City", in: app).waitForExistence(timeout: 10))
  }
}
