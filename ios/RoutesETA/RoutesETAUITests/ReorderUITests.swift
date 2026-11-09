import XCTest

/// Drag-to-reorder of commutes and routes, in their own class to keep
/// `RoutesETAUITests` under the type-length lint.
@MainActor
final class ReorderUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testCommutesCanBeReordered() throws {
    let app = launch()
    XCTAssertEqual(commuteTitles(in: app), ["Work to Home", "Home to Work"])

    app.buttons["Edit"].tap()
    dragRow(1, aboveRow: 0, in: app)
    app.buttons["Done"].tap()
    XCTAssertEqual(commuteTitles(in: app), ["Home to Work", "Work to Home"])
  }

  func testRoutesCanBeReordered() throws {
    let app = launch()
    app.staticTexts["Work to Home"].tap()
    XCTAssertTrue(app.staticTexts["City"].waitForExistence(timeout: 5))
    XCTAssertTrue(routeIsAbove("City", "Mordor", in: app))

    app.buttons["Edit"].tap()
    dragRow(1, aboveRow: 0, in: app)
    app.buttons["Done"].tap()
    XCTAssertTrue(routeIsAbove("Mordor", "City", in: app))
  }

  func testEditIsHiddenWhenThereIsNothingToReorder() throws {
    let app = launch()
    app.staticTexts["Home to Work"].tap()  // one route only
    XCTAssertTrue(app.buttons["add-route"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["Edit"].exists)
  }

  // MARK: - Helpers

  private func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-mock-services"]
    app.launch()
    XCTAssertTrue(app.staticTexts["Work to Home"].waitForExistence(timeout: 10))
    return app
  }

  /// Titles of the commute rows, top to bottom.
  private func commuteTitles(in app: XCUIApplication) -> [String] {
    ["Work to Home", "Home to Work"]
      .filter { app.staticTexts[$0].exists }
      .sorted { app.staticTexts[$0].frame.minY < app.staticTexts[$1].frame.minY }
  }

  private func routeIsAbove(_ upper: String, _ lower: String, in app: XCUIApplication) -> Bool {
    app.staticTexts[upper].frame.minY < app.staticTexts[lower].frame.minY
  }

  /// Drags a row's "Reorder …" handle (visible in edit mode) above another row's handle.
  private func dragRow(_ from: Int, aboveRow to: Int, in app: XCUIApplication) {
    let handles = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reorder '"))
    let source = handles.element(boundBy: from)
    let target = handles.element(boundBy: to)
    XCTAssertTrue(source.waitForExistence(timeout: 5))
    source.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
      forDuration: 0.5,
      thenDragTo: target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)))
  }
}
