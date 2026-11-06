import Domain
import Foundation
import Testing

@testable import Platform

struct FileConfigRepositoryTests {
  private func makeURL() -> URL {
    FileManager.default.temporaryDirectory
      .appending(path: "routes-eta-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
      .appending(path: "config.json", directoryHint: .notDirectory)
  }

  private let config = Config(commutes: [
    Commute(
      name: "Work to Home",
      origin: NamedPoint(label: "Work", lat: 19.4, lng: -99.1),
      destination: NamedPoint(label: "Home", lat: 19.5, lng: -99.2),
      routes: [RouteDef(name: "City", color: "#2563eb", via: [LatLng(lat: 19.45, lng: -99.15)])],
      schedules: [ScheduleRule(weekdays: [.mon, .tue], time: "18:30")])
  ])

  @Test func missingFileIsAnEmptyConfig() async throws {
    #expect(try await FileConfigRepository(url: makeURL()).load() == Config())
  }

  @Test func roundTripsIncludingSchedules() async throws {
    let repository = FileConfigRepository(url: makeURL())
    try await repository.save(config)
    #expect(try await repository.load() == config)
  }

  @Test func createsTheParentDirectory() async throws {
    let url = makeURL()
    try await FileConfigRepository(url: url).save(config)
    #expect(FileManager.default.fileExists(atPath: url.path))
  }

  @Test func laterSavesReplaceEarlierOnes() async throws {
    let repository = FileConfigRepository(url: makeURL())
    try await repository.save(config)
    try await repository.save(Config())
    #expect(try await repository.load() == Config())
  }

  @Test func corruptFileFailsToLoadInsteadOfLookingEmpty() async throws {
    let url = makeURL()
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("{ not json".utf8).write(to: url)
    await #expect(throws: DecodingError.self) {
      try await FileConfigRepository(url: url).load()
    }
  }

  @Test func invalidConfigIsRejectedAndTheOldFileKept() async throws {
    let repository = FileConfigRepository(url: makeURL())
    try await repository.save(config)

    var bad = config
    bad.commutes.append(bad.commutes[0])  // duplicate commute name
    await #expect(throws: ConfigRepositoryError.self) { try await repository.save(bad) }
    #expect(try await repository.load() == config)
  }

  @Test func fileUsesTheApiJsonKeys() async throws {
    let url = makeURL()
    try await FileConfigRepository(url: url).save(config)
    let text = try String(contentsOf: url, encoding: .utf8)
    for key in [
      "\"commutes\"", "\"origin\"", "\"routes\"", "\"via\"", "\"schedules\"", "\"weekdays\"",
    ] {
      #expect(text.contains(key))
    }
  }
}
