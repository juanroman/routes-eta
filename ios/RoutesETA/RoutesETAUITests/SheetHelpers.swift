import XCTest

extension XCUIApplication {
  /// The app opens on Home (the ETAs). Most tests are about one commute's screen, which is one
  /// tap away behind "Details": pick the commute in Home's selector, then open it.
  @MainActor
  func openCommute(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
    let details = buttons["home-details"]
    XCTAssertTrue(
      details.waitForExistence(timeout: 10), "Home never appeared", file: file, line: line)
    let segment = segmentedControls["home-selector"].buttons[name]
    if segment.exists, !segment.isSelected {
      segment.tap()
      XCTAssertTrue(
        NSPredicate(format: "isSelected == true").evaluate(with: segment)
          || segment.waitForExistence(timeout: 5),
        file: file, line: line)
    }
    details.tap()
    XCTAssertTrue(
      buttons["add-route"].waitForExistence(timeout: 10), "\(name) did not open", file: file,
      line: line)
  }

  /// Home's ⋯ menu: "home-add" (Add Commute…) or "home-manage" (Manage Commutes…).
  @MainActor
  func chooseFromHomeMenu(
    _ item: String, file: StaticString = #filePath, line: UInt = #line
  ) {
    let more = buttons["home-more"]
    XCTAssertTrue(more.waitForExistence(timeout: 10), "Home never appeared", file: file, line: line)
    more.tap()
    let entry = buttons[item]
    XCTAssertTrue(
      entry.waitForExistence(timeout: 5), "\(item) is not in the menu", file: file, line: line)
    entry.tap()
  }

  /// The commute screen's sheet starts small, showing only its title and the first rows; rows
  /// below that aren't on screen (and so aren't reachable) until it is pulled up. Always
  /// pulls it all the way up (pulling an already open sheet is harmless), and waits until
  /// its toolbar has moved up to the top of the screen: a partly visible row is in the
  /// accessibility tree, so its presence can't tell whether the sheet is open.
  @MainActor
  func expandCommuteSheet(file: StaticString = #filePath, line: UInt = #line) {
    let add = buttons["add-route"]
    XCTAssertTrue(
      add.waitForExistence(timeout: 10), "the sheet never appeared", file: file, line: line)
    let window = windows.firstMatch
    window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.76)).press(
      forDuration: 0.1,
      thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)))
    let deadline = Date().addingTimeInterval(5)
    while add.frame.minY > window.frame.height * 0.3, Date() < deadline {
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    XCTAssertLessThan(
      add.frame.minY, window.frame.height * 0.3, "the sheet did not open", file: file, line: line)
  }
}
