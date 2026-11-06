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
    name.typeText("\n")  // submit: commits the name and dismisses the keyboard
    let color = app.buttons["color-#16a34a"]
    XCTAssertTrue(color.waitForExistence(timeout: 5))
    color.tap()
    app.navigationBars.buttons.firstMatch.tap()  // back; commits the name

    let row = app.staticTexts["Toll Road"]
    XCTAssertTrue(row.waitForExistence(timeout: 5))

    // Delete asks first; Cancel keeps it, confirming removes it.
    row.swipeLeft()
    app.buttons["Delete"].tap()
    XCTAssertTrue(app.alerts.buttons["Delete Route"].waitForExistence(timeout: 5))
    app.alerts.buttons["Cancel"].tap()
    XCTAssertTrue(row.exists)

    // After Cancel the row may still be swiped open; only swipe if it isn't.
    if !app.buttons["Delete"].exists { row.swipeLeft() }
    app.buttons["Delete"].tap()
    XCTAssertTrue(app.alerts.buttons["Delete Route"].waitForExistence(timeout: 5))
    app.alerts.buttons["Delete Route"].tap()
    XCTAssertTrue(row.waitForNonExistence(timeout: 5))
  }

  @MainActor
  func testScheduleSectionIsHiddenByDefault() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-mock-services"]
    app.launch()
    app.staticTexts["Home to Work"].tap()

    XCTAssertTrue(app.buttons["show-etas"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["Mon · 06:30"].exists)
    XCTAssertFalse(app.staticTexts["Schedule"].exists)
  }

  @MainActor
  func testScheduleChipsRespectOtherRulesAndRulesCanBeAddedAndDeleted() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-mock-services", "-show-schedules"]
    app.launch()
    app.staticTexts["Home to Work"].tap()
    app.staticTexts["Mon · 06:30"].tap()

    // "Home to Work" has Mon (rule 1) and Tue-Fri (rule 2): rule 1 can't take Tue,
    // and Mon can't be switched off because it is rule 1's only day.
    XCTAssertFalse(app.buttons["day-0-Tue"].isEnabled)
    XCTAssertFalse(app.buttons["day-0-Mon"].isEnabled)
    XCTAssertTrue(app.buttons["day-0-Sat"].isEnabled)

    // Sat and Sun are free, so a third rule can be added and gets Sat.
    app.buttons["day-0-Sat"].tap()
    XCTAssertTrue(app.buttons["day-0-Mon"].isEnabled)  // now has two days
    app.buttons["day-0-Sat"].tap()  // back off

    app.buttons["add-rule"].tap()
    XCTAssertTrue(app.buttons["day-2-Sat"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["day-2-Sat"].isSelected)
    XCTAssertFalse(app.buttons["day-2-Mon"].isEnabled)

    // Delete it, with confirmation.
    app.buttons.matching(identifier: "Delete Rule").element(boundBy: 2).tap()
    XCTAssertTrue(app.alerts.buttons["Delete Rule"].waitForExistence(timeout: 5))
    app.alerts.buttons["Cancel"].tap()
    XCTAssertTrue(app.buttons["day-2-Sat"].exists)
    app.buttons.matching(identifier: "Delete Rule").element(boundBy: 2).tap()
    app.alerts.buttons["Delete Rule"].tap()
    XCTAssertTrue(app.buttons["day-2-Sat"].waitForNonExistence(timeout: 5))
  }

  @MainActor
  func testShowETAsListsEachRouteAndCanBeRefreshed() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-mock-services"]
    app.launch()
    app.staticTexts["Work to Home"].tap()

    let button = app.buttons["show-etas"]
    XCTAssertTrue(button.waitForExistence(timeout: 5))
    XCTAssertTrue(button.isEnabled)
    button.tap()

    // One chip per route, in the commute's order, each with minutes.
    let city = app.descendants(matching: .any)["eta-City"]
    XCTAssertTrue(city.waitForExistence(timeout: 10))
    XCTAssertTrue(city.label.contains("min"))
    let mordor = app.descendants(matching: .any)["eta-Mordor"]
    XCTAssertTrue(mordor.exists)
    // Exactly one of the two chips is marked as the quickest.
    XCTAssertNotEqual(city.label.contains("Fastest"), mordor.label.contains("Fastest"))

    app.buttons["eta-refresh"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["eta-City"].waitForExistence(timeout: 10))

    app.buttons["Done"].tap()
    XCTAssertTrue(button.waitForExistence(timeout: 5))
  }

  @MainActor
  func testShowETAsIsDisabledUntilTheCommuteIsComplete() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-mock-services"]
    app.launch()

    app.buttons["Add Commute"].tap()
    let field = app.alerts.textFields["Name"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.typeText("Gym")
    app.alerts.buttons["Add"].tap()
    app.staticTexts["Gym"].tap()

    XCTAssertFalse(app.buttons["show-etas"].isEnabled)
    XCTAssertTrue(app.staticTexts["Set origin and destination first"].exists)
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
