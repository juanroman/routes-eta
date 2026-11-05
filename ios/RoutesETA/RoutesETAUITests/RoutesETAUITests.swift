import XCTest

final class RoutesETAUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testDrillIntoACommuteAndBack() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-mock-services"]
    app.launch()

    let commute = app.staticTexts["Work to Home"]
    XCTAssertTrue(commute.waitForExistence(timeout: 10))
    commute.tap()

    XCTAssertTrue(app.buttons["Show ETAs"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["City"].exists)

    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(app.navigationBars["Commutes"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testDeleteAsksForConfirmation() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-mock-services"]
    app.launch()

    let commute = app.staticTexts["Home to Work"]
    XCTAssertTrue(commute.waitForExistence(timeout: 10))
    commute.swipeLeft()
    app.buttons["Delete"].tap()

    // Cancelling keeps the commute.
    XCTAssertTrue(app.buttons["Delete Commute"].waitForExistence(timeout: 5))
    app.buttons["Cancel"].tap()
    XCTAssertTrue(commute.waitForExistence(timeout: 5))

    // Confirming removes it.
    commute.swipeLeft()
    app.buttons["Delete"].tap()
    app.buttons["Delete Commute"].tap()
    XCTAssertTrue(commute.waitForNonExistence(timeout: 5))
  }

  @MainActor
  func testSearchForADestinationAndRenameFromDetail() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-mock-services"]
    app.launch()

    app.staticTexts["Work to Home"].tap()

    // Search like Calendar's Location field, then pick a result.
    app.buttons["endpoint-To"].tap()
    let search = app.searchFields.firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    search.tap()
    search.typeText("Pola")
    let result = app.buttons["place-Polanco"]
    XCTAssertTrue(result.waitForExistence(timeout: 5))
    result.tap()
    waitForLabel(of: app.buttons["endpoint-To"], toContain: "Polanco")

    // Rename via the menu.
    app.buttons["More"].tap()
    app.buttons["Rename"].tap()
    let field = app.alerts.textFields["Name"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.clearAndType("Evening")
    app.alerts.buttons["Rename"].tap()
    XCTAssertTrue(app.navigationBars["Evening"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testHomeShortcutIsSetOnceThenReused() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-mock-services"]
    app.launch()
    app.staticTexts["Work to Home"].tap()

    // First use: Home is unset, so tapping it asks for an address.
    app.buttons["endpoint-From"].tap()
    app.buttons["shortcut-Home"].tap()
    let search = app.searchFields.firstMatch
    search.tap()
    search.typeText("Sat")
    app.buttons["place-Satélite"].tap()
    waitForLabel(of: app.buttons["endpoint-From"], toContain: "Home")

    // Second use: the shortcut now fills the field directly, no search.
    app.buttons["endpoint-To"].tap()
    XCTAssertTrue(app.buttons["shortcut-Home"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["shortcut-Home"].label.contains("Mexico City"))
    app.buttons["shortcut-Home"].tap()
    waitForLabel(of: app.buttons["endpoint-To"], toContain: "Home")
  }

  @MainActor
  func testAddRenameRecolorAndDeleteARoute() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-mock-services"]
    app.launch()
    app.staticTexts["Home to Work"].tap()

    // Adding opens the new route's editor.
    app.buttons["add-route"].tap()
    let name = app.textFields["route-name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    XCTAssertEqual(name.value as? String, "Route 2")

    name.clearAndType("Toll Road")
    app.buttons["color-#16a34a"].tap()
    app.navigationBars.buttons.firstMatch.tap()  // back; commits the name

    let row = app.staticTexts["Toll Road"]
    XCTAssertTrue(row.waitForExistence(timeout: 5))

    // Delete asks first; Cancel keeps it, confirming removes it.
    row.swipeLeft()
    app.buttons["Delete"].tap()
    XCTAssertTrue(app.alerts.buttons["Delete Route"].waitForExistence(timeout: 5))
    app.alerts.buttons["Cancel"].tap()
    XCTAssertTrue(row.exists)

    row.swipeLeft()
    app.buttons["Delete"].tap()
    app.alerts.buttons["Delete Route"].tap()
    XCTAssertTrue(row.waitForNonExistence(timeout: 5))
  }

  private func waitForLabel(
    of element: XCUIElement, toContain text: String, file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let predicate = NSPredicate(format: "label CONTAINS %@", text)
    let result = XCTWaiter().wait(
      for: [expectation(for: predicate, evaluatedWith: element)], timeout: 5)
    XCTAssertEqual(result, .completed, file: file, line: line)
  }
}

extension XCUIElement {
  func clearAndType(_ text: String) {
    tap()
    let current = (value as? String) ?? ""
    typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + text)
  }
}
