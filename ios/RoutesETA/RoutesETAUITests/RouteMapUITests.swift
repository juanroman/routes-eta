import XCTest

/// Map editing: via points inline and full screen, and the camera shared between them.
final class RouteMapUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testAddDragAndRemoveAViaPointOnTheMap() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-mock-services"]
    app.launch()
    app.openCommutesList()
    app.staticTexts["Work to Home"].tap()
    app.expandCommuteSheet()
    app.buttons["edit-route-Mordor"].tap()  // a direct route: a straight line, no via points

    let count = app.staticTexts["via-count"]
    XCTAssertTrue(count.waitForExistence(timeout: 10))
    XCTAssertEqual(count.label, "No via points")

    // The map is fitted to the route and centered on the *visible* area (the map
    // is 340pt tall and extends under the nav bar), so a straight line between the
    // two ends passes through the center of that bottom 340pt.
    let map = app.maps.firstMatch
    XCTAssertTrue(map.waitForExistence(timeout: 5))
    sleep(2)  // let the preview polyline load and the camera settle
    let centerY = (map.frame.height - 340 / 2) / map.frame.height
    map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: centerY)).tap()

    let handle = app.staticTexts["via-handle-0"]
    XCTAssertTrue(handle.waitForExistence(timeout: 5))
    XCTAssertEqual(count.label, "1 via point")

    // Tapping the handle selects it and must not add a second via point.
    handle.tap()
    XCTAssertTrue(app.buttons["remove-via"].waitForExistence(timeout: 5))
    XCTAssertEqual(count.label, "1 via point")

    // Dragging moves it without panning the map or adding points.
    let before = handle.frame
    let grip = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    grip.press(forDuration: 0.2, thenDragTo: grip.withOffset(CGVector(dx: 60, dy: 40)))
    sleep(1)
    XCTAssertGreaterThan(app.staticTexts["via-handle-0"].frame.midX, before.midX + 30)
    XCTAssertEqual(count.label, "1 via point")

    // Remove it.
    app.buttons["remove-via"].tap()
    XCTAssertEqual(count.label, "No via points")
  }

  @MainActor
  func testEditViaPointsFullScreenAndComeBack() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-mock-services"]
    app.launch()
    app.openCommutesList()
    app.staticTexts["Work to Home"].tap()
    app.expandCommuteSheet()
    app.buttons["edit-route-Mordor"].tap()  // a direct route: a straight line, no via points

    // While the cover is up the inline screen is still in the accessibility tree, so
    // these ids can match twice; look at all matches.
    func labels(_ id: String) -> [String] {
      app.staticTexts.matching(identifier: id).allElementsBoundByIndex.map(\.label)
    }
    XCTAssertTrue(app.staticTexts["via-count"].waitForExistence(timeout: 10))
    XCTAssertEqual(labels("via-count"), ["No via points"])

    app.buttons["expand-map"].tap()
    XCTAssertTrue(app.buttons["collapse-map"].waitForExistence(timeout: 5))
    sleep(2)  // let the preview polyline load and the camera settle

    // Full screen the map fills the window, so its center is the window's center and a
    // straight line between the two ends passes through it.
    app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    XCTAssertTrue(app.staticTexts["via-handle-0"].firstMatch.waitForExistence(timeout: 5))
    XCTAssertTrue(labels("via-count").contains("1 via point"))

    app.buttons["collapse-map"].tap()
    XCTAssertTrue(app.buttons["expand-map"].waitForExistence(timeout: 5))
    XCTAssertEqual(labels("via-count"), ["1 via point"])  // same edit, same data
    XCTAssertTrue(app.staticTexts["via-handle-0"].exists)
  }

  @MainActor
  func testFullScreenKeepsTheZoomedViewAndStillZooms() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-mock-services"]
    app.launch()
    app.openCommutesList()
    app.staticTexts["Work to Home"].tap()
    app.expandCommuteSheet()
    app.buttons["edit-route-City"].tap()
    XCTAssertTrue(app.maps.firstMatch.waitForExistence(timeout: 10))
    sleep(3)

    // Regression: after zooming the inline map, expanding it used to show the whole world.
    app.maps.firstMatch.pinch(withScale: 2.0, velocity: 1.0)
    sleep(1)
    app.buttons["expand-map"].tap()
    XCTAssertTrue(app.buttons["collapse-map"].waitForExistence(timeout: 5))
    sleep(3)
    let opened = zoomLevels(of: app)
    XCTAssertFalse(opened.isEmpty)
    XCTAssertTrue(opened.allSatisfy { $0 > 9 }, "map opened at zoom levels \(opened)")

    // And zooming works full screen.
    app.windows.firstMatch.pinch(withScale: 2.0, velocity: 1.0)
    sleep(1)
    let zoomed = zoomLevels(of: app)
    XCTAssertGreaterThan(zoomed.max() ?? 0, (opened.max() ?? 0) + 0.5, "zoom did not change")
  }

  /// The map's accessibility value is JSON including `"zoom":N`; ~13 is a city, ~4 the world.
  private func zoomLevels(of app: XCUIApplication) -> [Double] {
    app.maps.allElementsBoundByIndex.compactMap { map in
      let text = (map.value as? String) ?? ""
      guard let range = text.range(of: #""zoom":[0-9.]+"#, options: .regularExpression) else {
        return nil
      }
      return Double(text[range].dropFirst(7))
    }
  }
}
