import XCTest

extension XCUIApplication {
  /// The app opens on Home (the ETAs). Most tests are about the commutes list, which is one tap
  /// away behind "Edit".
  @MainActor
  func openCommutesList(file: StaticString = #filePath, line: UInt = #line) {
    let edit = buttons["Edit"]
    XCTAssertTrue(
      edit.waitForExistence(timeout: 10), "Home never appeared", file: file, line: line)
    edit.tap()
    XCTAssertTrue(
      navigationBars["Commutes"].waitForExistence(timeout: 5), "the commutes list did not open",
      file: file, line: line)
  }

  /// The commute screen's sheet starts small, showing only its title and the first rows; rows
  /// below that aren't on screen (and so aren't reachable) until it is pulled up. Always
  /// pulls it all the way up: a partly visible row (like Show ETAs at the small detent) is
  /// in the accessibility tree, so its presence can't tell whether the sheet is open; and
  /// pulling an already open sheet is harmless.
  @MainActor
  func expandCommuteSheet(file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(
      buttons["add-route"].waitForExistence(timeout: 10), "the sheet never appeared",
      file: file, line: line)
    let window = windows.firstMatch
    window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.76)).press(
      forDuration: 0.1,
      thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)))
    XCTAssertTrue(
      buttons["show-etas"].waitForExistence(timeout: 5), "the sheet did not open",
      file: file, line: line)
  }
}
