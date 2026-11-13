import XCTest

/// The commute screen: routes on the map, the persistent sheet, and handing over to the
/// route editor and back.
@MainActor
final class CommuteMapUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  /// With `expanded` the sheet is pulled up so every row is reachable; without it the sheet
  /// is left small, as it opens.
  private func openWorkToHome(expanded: Bool = true) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-mock-services"]
    app.launch()
    app.staticTexts["Work to Home"].tap()
    if expanded {
      app.expandCommuteSheet()
    } else {
      XCTAssertTrue(app.buttons["endpoint-From"].waitForExistence(timeout: 10))
    }
    return app
  }

  func testTappingARouteRowSelectsItAndTappingAgainClearsIt() throws {
    let app = openWorkToHome()
    let mordor = app.buttons["Mordor"]
    XCTAssertFalse(mordor.isSelected)

    mordor.tap()
    XCTAssertTrue(mordor.isSelected)
    XCTAssertFalse(app.buttons["City"].isSelected)

    // Selecting another moves the selection; tapping the selected one clears it.
    app.buttons["City"].tap()
    XCTAssertTrue(app.buttons["City"].isSelected)
    XCTAssertFalse(mordor.isSelected)
    app.buttons["City"].tap()
    XCTAssertFalse(app.buttons["City"].isSelected)
  }

  func testTheEditButtonOpensTheEditorAndTheSheetComesBack() throws {
    let app = openWorkToHome()

    app.buttons["edit-route-City"].tap()
    XCTAssertTrue(app.textFields["route-name"].waitForExistence(timeout: 5))
    // The sheet belongs to the commute screen and must not cover the editor.
    XCTAssertFalse(app.buttons["show-etas"].exists)

    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(app.buttons["show-etas"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["City"].exists)
  }

  func testTheETAsOpenOverTheSheet() throws {
    let app = openWorkToHome()
    app.buttons["show-etas"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["eta-City"].waitForExistence(timeout: 10))
    app.buttons["Done"].tap()
    XCTAssertTrue(app.buttons["show-etas"].waitForExistence(timeout: 5))
  }

  /// "Work to Home" has one direct route (Mordor) and one through a via point (City), so
  /// the straight line passes through the middle of the framed content. With the routes
  /// fitted in the part of the map the sheet leaves uncovered, that middle is the centre
  /// of the uncovered part: a tap there selects Mordor.
  func testTappingTheRouteOnTheMapSelectsIt() throws {
    let app = openWorkToHome(expanded: false)
    sleep(2)  // let the lines load and the camera settle

    let window = app.windows.firstMatch.frame
    let top = app.navigationBars.buttons["Commutes"].frame.maxY
    let uncoveredBottom = window.height - 230
    let centre = CGVector(dx: 0.5, dy: (top + (uncoveredBottom - top) / 2) / window.height)
    app.windows.firstMatch.coordinate(withNormalizedOffset: centre).tap()

    // The sheet scrolls the selected row into view, even while it is small.
    let mordor = app.buttons["Mordor"]
    XCTAssertTrue(mordor.waitForExistence(timeout: 5))
    XCTAssertTrue(mordor.isSelected)
  }
}
