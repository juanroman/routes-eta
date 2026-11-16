import XCTest

/// The app in Spanish (Mexico): the compiled catalog is in the bundle, and text from the package,
/// from the Domain wording and from the system's own controls all come out translated.
@MainActor
final class LocalizationUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  private func launchInSpanish() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "-AppleLanguages", "(es-MX)", "-AppleLocale", "es_MX",
      "-mock-services", "-mock-location", "work",
    ]
    app.launch()
    return app
  }

  func testHomeSpeaksSpanish() throws {
    let app = launchInSpanish()
    // The place name is the person's data ("Work"); the sentence around it is ours.
    XCTAssertTrue(app.staticTexts["home-reason"].waitForExistence(timeout: 10))
    XCTAssertEqual(app.staticTexts["home-reason"].label, "Cerca de Work")
    // "Actualizado hace …": the freshness footer, built from Domain's RelativeAge wording.
    let updated = app.staticTexts["home-updated"]
    XCTAssertTrue(updated.waitForExistence(timeout: 10))
    XCTAssertTrue(updated.label.hasPrefix("Actualizado"), updated.label)
    XCTAssertTrue(app.buttons["home-details"].label == "Detalles")
  }

  func testMenuAndSystemControlsAreSpanish() throws {
    let app = launchInSpanish()
    XCTAssertTrue(app.buttons["home-more"].waitForExistence(timeout: 10))
    app.buttons["home-more"].tap()
    XCTAssertTrue(app.buttons["home-add"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.buttons["home-add"].label, "Agregar trayecto…")
    XCTAssertEqual(app.buttons["home-manage"].label, "Administrar trayectos…")
  }
}
