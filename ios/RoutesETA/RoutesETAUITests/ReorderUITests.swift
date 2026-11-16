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
    XCTAssertEqual(selectorOrder(in: app), ["Work to Home", "Home to Work"])

    app.chooseFromHomeMenu("home-manage")
    XCTAssertEqual(commuteTitles(in: app), ["Work to Home", "Home to Work"])
    dragRow(1, aboveRow: 0, in: app)
    XCTAssertEqual(commuteTitles(in: app), ["Home to Work", "Work to Home"])
    app.buttons["Done"].tap()
    // Home's selector follows the new order.
    XCTAssertTrue(app.buttons["home-more"].waitForExistence(timeout: 5))
    XCTAssertEqual(selectorOrder(in: app), ["Home to Work", "Work to Home"])
  }

  func testRoutesCanBeReordered() throws {
    let app = launch()
    app.openCommute("Work to Home")
    app.expandCommuteSheet()
    XCTAssertTrue(app.buttons["City"].waitForExistence(timeout: 5))
    XCTAssertTrue(routeIsAbove("City", "Mordor", in: app))

    app.buttons["Edit"].tap()
    dragRow(1, aboveRow: 0, in: app)
    app.buttons["Done"].tap()
    XCTAssertTrue(routeIsAbove("Mordor", "City", in: app))
  }

  /// Edit isn't only for reordering: it also shows the places, so it is there with one route.
  func testEditIsAvailableEvenWithOneRoute() throws {
    let app = launch()
    app.openCommute("Home to Work")  // one route only
    XCTAssertTrue(app.buttons["Edit"].exists)
  }

  // MARK: - Helpers

  private func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-mock-services"]
    app.launch()
    XCTAssertTrue(app.buttons["home-more"].waitForExistence(timeout: 10))
    return app
  }

  /// The commutes in Home's selector, left to right.
  private func selectorOrder(in app: XCUIApplication) -> [String] {
    let buttons = app.segmentedControls["home-selector"].buttons
    return ["Work to Home", "Home to Work"]
      .filter { buttons[$0].exists }
      .sorted { buttons[$0].frame.minX < buttons[$1].frame.minX }
  }

  /// Titles of the commute rows in Manage Commutes, top to bottom.
  private func commuteTitles(in app: XCUIApplication) -> [String] {
    ["Work to Home", "Home to Work"]
      .filter { app.staticTexts[$0].exists }
      .sorted { app.staticTexts[$0].frame.minY < app.staticTexts[$1].frame.minY }
  }

  private func routeIsAbove(_ upper: String, _ lower: String, in app: XCUIApplication) -> Bool {
    app.buttons[upper].frame.minY < app.buttons[lower].frame.minY
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
