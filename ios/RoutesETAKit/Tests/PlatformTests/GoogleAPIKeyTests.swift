import Foundation
import Testing

@testable import Platform

struct GoogleAPIKeyTests {
  private func plist(_ entries: [String: Any]) throws -> Data {
    try PropertyListSerialization.data(fromPropertyList: entries, format: .xml, options: 0)
  }

  @Test func readsAndTrimsTheKey() throws {
    let data = try plist([GoogleAPIKey.plistKey: "  abc123\n"])
    #expect(try GoogleAPIKey.parse(data) == "abc123")
  }

  @Test(arguments: ["", "   ", "YOUR_KEY_HERE"])
  func emptyOrTemplateValuesCountAsMissing(value: String) throws {
    let data = try plist([GoogleAPIKey.plistKey: value])
    #expect(throws: GoogleAPIKey.Failure.missingKey) { try GoogleAPIKey.parse(data) }
  }

  @Test func absentKeyIsMissing() throws {
    let data = try plist(["OTHER": "x"])
    #expect(throws: GoogleAPIKey.Failure.missingKey) { try GoogleAPIKey.parse(data) }
  }

  @Test func nonStringValueIsMissing() throws {
    let data = try plist([GoogleAPIKey.plistKey: 42])
    #expect(throws: GoogleAPIKey.Failure.missingKey) { try GoogleAPIKey.parse(data) }
  }

  @Test func garbageIsUnreadable() {
    #expect(throws: GoogleAPIKey.Failure.unreadable) {
      try GoogleAPIKey.parse(Data("not a plist".utf8))
    }
  }

  @Test func bundleWithoutTheFileReportsItMissing() {
    let empty = Bundle(for: BundleToken.self)  // the test bundle has no Secrets.plist
    #expect(throws: GoogleAPIKey.Failure.missingFile) { try GoogleAPIKey.load(from: empty) }
  }

  @Test func errorsTellTheUserWhatToDo() {
    #expect(GoogleAPIKey.Failure.missingFile.errorDescription?.contains("Secrets.plist") == true)
  }
}

private final class BundleToken {}
