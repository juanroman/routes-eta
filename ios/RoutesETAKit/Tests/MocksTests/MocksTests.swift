import Domain
import Foundation
import Testing

@testable import Mocks

struct MocksTests {
  /// `fixtures/sample-config.json` is the contract shared with api/ and web/.
  @Test func sampleDataMatchesTheSharedFixture() throws {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<5 { url.deleteLastPathComponent() }
    url.appendPathComponent("fixtures/sample-config.json")
    let fixture = try JSONDecoder().decode(Config.self, from: Data(contentsOf: url))
    #expect(fixture == SampleData.config)
    #expect(fixture.validate().isEmpty)
  }

  @Test func repositoryReturnsSeedAndPersistsSaves() async throws {
    let repository = InMemoryConfigRepository()
    #expect(try await repository.load() == SampleData.config)

    var changed = SampleData.config
    changed.commutes.removeLast()
    try await repository.save(changed)
    #expect(try await repository.load() == changed)
  }

  @Test func repositoryRejectsInvalidConfigAndKeepsOldState() async throws {
    let repository = InMemoryConfigRepository()
    var bad = SampleData.config
    bad.commutes.append(bad.commutes[0])
    await #expect(throws: ConfigRepositoryError.self) { try await repository.save(bad) }
    #expect(try await repository.load() == SampleData.config)
  }

  @Test func previewPassesThroughViaPointsInOrder() async throws {
    let origin = SampleData.work.latLng
    let destination = SampleData.home.latLng
    let via = [LatLng(lat: 19.45, lng: -99.2), LatLng(lat: 19.48, lng: -99.22)]
    let preview = try await MockRoutePreviewService().preview(
      origin: origin, destination: destination, via: via)
    #expect(preview.polyline == [origin] + via + [destination])
    #expect(preview.distanceMeters > 0)
  }

  @Test func previewIsDeterministic() async throws {
    let service = MockRoutePreviewService()
    let first = try await service.preview(
      origin: SampleData.work.latLng, destination: SampleData.home.latLng, via: [])
    let second = try await service.preview(
      origin: SampleData.work.latLng, destination: SampleData.home.latLng, via: [])
    #expect(first == second)
  }

  @Test func etasFollowConfigOrderAndFormatTheMessage() async throws {
    let service = MockETAService(repository: InMemoryConfigRepository())
    let report = try await service.run(commute: "Work to Home")
    #expect(report.results.map(\.name) == ["City", "Mordor"])
    #expect(report.results.allSatisfy { ($0.minutes ?? 0) > 0 })
    #expect(report.message.hasPrefix("Work to Home: City "))
    #expect(report.message.contains(" · Mordor "))
  }

  @Test func unknownCommuteThrows() async {
    let service = MockETAService(repository: InMemoryConfigRepository())
    await #expect(throws: ETAServiceError.unknownCommute("Nope")) {
      try await service.run(commute: "Nope")
    }
  }

  @Test func aFailingRouteShowsQuestionMarkAndOthersStillReport() async throws {
    let config = Config(commutes: [
      Commute(
        name: "C",
        routes: [
          RouteDef(name: "Good", color: "#000000"), RouteDef(name: "Fail", color: "#111111"),
        ])
    ])
    let service = MockETAService(repository: InMemoryConfigRepository(initial: config))
    let report = try await service.run(commute: "C")
    #expect(report.results[1].minutes == nil)
    #expect(report.results[1].error != nil)
    #expect(report.message.hasSuffix(" · Fail ?"))
  }

  @Test func allRoutesFailingGivesTheFailureMessage() async throws {
    let config = Config(commutes: [
      Commute(name: "C", routes: [RouteDef(name: "Fail", color: "#111111")])
    ])
    let service = MockETAService(repository: InMemoryConfigRepository(initial: config))
    #expect(try await service.run(commute: "C").message == "C: Couldn't fetch ETAs")
  }
}
