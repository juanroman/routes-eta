import Foundation
import Testing

@testable import Features

@MainActor
struct TapStudyLogTests {
  private func makeLog(
    capacity: Int = 500, enabled: Bool = true, url: URL? = nil
  ) -> (TapStudyLog, URL) {
    let file = url ?? FileManager.default.temporaryDirectory.appending(path: "ts-\(UUID()).json")
    let defaults = UserDefaults(suiteName: "tap-study.tests.\(UUID())") ?? .standard
    let log = TapStudyLog(url: file, defaults: defaults, capacity: capacity)
    log.isEnabled = enabled
    return (log, file)
  }

  @Test func disabledRecordsNothing() {
    let (log, _) = makeLog(enabled: false)
    log.record(.tap, at: CGPoint(x: 1, y: 2))
    log.record(.flag)
    #expect(log.events.isEmpty)
  }

  @Test func recordsTouchMeasurementsAndContext() throws {
    let (log, _) = makeLog()
    log.context = TapStudyContext(screen: .full, metresPerPoint: 12.345, vertices: 7, viaCount: 2)
    log.record(
      .touch, at: CGPoint(x: 10.04, y: 20.06),
      touch: TapTouch(distToLine: 31.26, distToHandle: nil, travel: 4, duration: 0.1234))
    let event = try #require(log.events.first)
    #expect(event.kind == .touch)
    #expect(event.screen == .full)
    #expect(event.vertices == 7)
    #expect(event.viaCount == 2)
    #expect(event.metresPerPoint == 12.35)
    #expect(event.x == 10.0)
    #expect(event.y == 20.1)
    #expect(event.distToLine == 31.3)
    #expect(event.duration == 0.123)
    #expect(event.cancelled == nil)
  }

  @Test func ringBufferDropsTheOldest() {
    let (log, _) = makeLog(capacity: 3)
    for index in 0..<5 { log.record(.tap, at: CGPoint(x: Double(index), y: 0)) }
    #expect(log.events.map(\.x) == [2, 3, 4])
  }

  @Test func clearEmptiesTheLogAndItsFile() {
    let (log, file) = makeLog()
    log.record(.flag)
    log.flush()
    #expect(FileManager.default.fileExists(atPath: file.path))
    log.clear()
    #expect(log.events.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: file.path))
  }

  @Test func eventsSurviveARestart() {
    let (log, file) = makeLog()
    log.record(.flag)
    log.record(.tap, at: CGPoint(x: 5, y: 6))
    log.flush()
    let (reloaded, _) = makeLog(url: file)
    #expect(reloaded.events.map(\.kind) == [.flag, .tap])
  }

  @Test func viaEditsAreClassifiedByWhatChanged() {
    let (log, _) = makeLog()
    log.recordViaChange(from: [1], to: [1, 2])
    log.recordViaChange(from: [1, 2], to: [1, 3])
    log.recordViaChange(from: [1, 3], to: [1])
    log.recordViaChange(from: [1], to: [1])
    #expect(log.events.map(\.kind) == [.viaAdded, .viaMoved, .viaRemoved])
    #expect(log.events.map(\.viaCount) == [2, 2, 1])
  }

  /// The export is meant to be shared, so it must never carry a location.
  @Test func exportHasNoCoordinates() throws {
    let (log, _) = makeLog()
    log.record(.touch, at: .zero, touch: TapTouch(distToLine: 1, distToHandle: 2, travel: 3))
    log.record(.viaAdded)
    let text = try #require(String(data: log.exportData(), encoding: .utf8))
    for forbidden in ["lat", "lng", "latitude", "longitude", "label", "name"] {
      #expect(!text.contains("\"\(forbidden)\""), "export contains \(forbidden)")
    }
    let decoded = try JSONDecoder().decode(TapStudyExport.self, from: log.exportData())
    #expect(decoded.schemaVersion == 1)
    #expect(decoded.hitRadiusPt == 30)
    #expect(decoded.events.count == 2)
  }
}

/// The study is temporary; this keeps its footprint in the rest of the app at exactly
/// the hooks that `ios/tools/tap-study/REMOVING.md` lists, so removal stays mechanical.
struct TapStudyRemovalTests {
  static let documentedHooks = 5

  @Test func hooksOutsideTheStudyDirectoryAreTheDocumentedOnes() throws {
    // .../ios/RoutesETAKit/Tests/FeaturesTests/TapStudy/<this file>
    let ios = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    var hooks = 0
    for folder in ["RoutesETAKit/Sources", "RoutesETA/RoutesETA"] {
      let root = ios.appending(path: folder)
      let enumerator = try #require(FileManager.default.enumerator(atPath: root.path))
      for case let path as String in enumerator
      where path.hasSuffix(".swift") && !path.contains("TapStudy/") {
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        hooks += text.components(separatedBy: "TAP-STUDY").count - 1
      }
    }
    #expect(hooks == Self.documentedHooks)
  }
}
