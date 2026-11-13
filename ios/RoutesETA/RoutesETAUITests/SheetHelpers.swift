import XCTest

extension XCUIApplication {
  /// The commute screen's sheet starts small, showing only its title and the trip; rows
  /// below that aren't on screen (and so aren't reachable) until it is pulled up.
  /// Does nothing if it is already open far enough.
  @MainActor
  func expandCommuteSheet(file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(
      buttons["endpoint-From"].waitForExistence(timeout: 10), "the sheet never appeared",
      file: file, line: line)
    if buttons["show-etas"].exists { return }
    let window = windows.firstMatch
    window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.76)).press(
      forDuration: 0.1,
      thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)))
    XCTAssertTrue(
      buttons["show-etas"].waitForExistence(timeout: 5), "the sheet did not open",
      file: file, line: line)
  }
}
