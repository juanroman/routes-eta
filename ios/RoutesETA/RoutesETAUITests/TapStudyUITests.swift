import XCTest

/// Temporary tap-study instrumentation (see ios/tools/tap-study/REMOVING.md): events are
/// recorded, and the observer gesture leaves panning alone.
final class TapStudyUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  private func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-mock-services", "-tap-study-on"]
    app.launch()
    return app
  }

  /// Reads the count from the study sheet on the commutes list, then closes it.
  @MainActor
  private func recordedEvents(in app: XCUIApplication) -> Int {
    app.buttons["tap-study-menu"].tap()
    let count = app.staticTexts["tap-study-count"]
    XCTAssertTrue(count.waitForExistence(timeout: 5))
    let value = Int(count.label) ?? -1
    app.buttons["Done"].tap()
    return value
  }

  @MainActor
  func testRecordsTouchesTapsViaEditsAndFlags() throws {
    let app = launch()
    XCTAssertEqual(recordedEvents(in: app), 0)

    app.staticTexts["Work to Home"].tap()
    app.staticTexts["Mordor"].tap()  // a direct route: a straight line, no via points
    XCTAssertTrue(app.staticTexts["via-count"].waitForExistence(timeout: 10))
    let map = app.maps.firstMatch
    XCTAssertTrue(map.waitForExistence(timeout: 5))
    sleep(2)  // let the preview polyline load and the camera settle

    // On the line: a touch, the map's tap and the via edit.
    let centerY = (map.frame.height - 340 / 2) / map.frame.height
    let center = map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: centerY))
    center.tap()
    XCTAssertTrue(app.staticTexts["via-handle-0"].waitForExistence(timeout: 5))

    // 70pt from the line (it runs down-right here) and clear of the handle: the map's tap
    // handler still fires, but no via point is added.
    center.withOffset(CGVector(dx: -70, dy: 70)).tap()
    sleep(1)
    XCTAssertEqual(app.staticTexts["via-count"].label, "1 via point")

    app.buttons["tap-study-flag"].tap()

    app.navigationBars.buttons.element(boundBy: 0).tap()  // back to the commute
    app.navigationBars.buttons.element(boundBy: 0).tap()  // back to the list
    // touch + tap + viaAdded, then touch + tap (the miss), then the flag.
    XCTAssertEqual(recordedEvents(in: app), 6)
  }

  /// The observer sits beside the handle's own gestures; they must keep working.
  @MainActor
  func testHandlesStillSelectAndDragWhileRecording() throws {
    let app = launch()
    app.staticTexts["Work to Home"].tap()
    app.staticTexts["Mordor"].tap()
    let count = app.staticTexts["via-count"]
    XCTAssertTrue(count.waitForExistence(timeout: 10))
    let map = app.maps.firstMatch
    XCTAssertTrue(map.waitForExistence(timeout: 5))
    sleep(2)
    let centerY = (map.frame.height - 340 / 2) / map.frame.height
    map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: centerY)).tap()

    let handle = app.staticTexts["via-handle-0"]
    XCTAssertTrue(handle.waitForExistence(timeout: 5))
    handle.tap()
    XCTAssertTrue(app.buttons["remove-via"].waitForExistence(timeout: 5))
    XCTAssertEqual(count.label, "1 via point")

    let before = handle.frame
    let grip = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    grip.press(forDuration: 0.2, thenDragTo: grip.withOffset(CGVector(dx: 60, dy: 40)))
    sleep(1)
    XCTAssertGreaterThan(app.staticTexts["via-handle-0"].frame.midX, before.midX + 30)
    XCTAssertEqual(count.label, "1 via point")
  }

  @MainActor
  func testObservingTouchesDoesNotStopTheMapFromPanning() throws {
    let app = launch()
    app.staticTexts["Work to Home"].tap()
    app.staticTexts["City"].tap()
    let map = app.maps.firstMatch
    XCTAssertTrue(map.waitForExistence(timeout: 10))
    sleep(3)

    let before = map.value as? String
    map.swipeLeft()
    sleep(1)
    XCTAssertNotEqual(map.value as? String, before, "the map did not move")
  }
}
