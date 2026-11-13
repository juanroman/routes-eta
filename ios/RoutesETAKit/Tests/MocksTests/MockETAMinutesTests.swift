import Domain
import Testing

@testable import Mocks

struct MockETAMinutesTests {
  private let origin = SampleData.work.latLng
  private let destination = SampleData.home.latLng

  @Test func aRouteGetsTheSameMinutesAsInTheFullReport() async throws {
    let service = MockETAService(repository: InMemoryConfigRepository())
    let report = try await service.run(commute: "Work to Home")

    for result in report.results {
      let route = try #require(
        SampleData.config.commutes[0].routes.first { $0.name == result.name })
      let minutes = try await service.minutes(for: route, from: origin, to: destination)
      #expect(minutes == result.minutes)
    }
  }

  @Test func aRouteNamedFailFails() async {
    let service = MockETAService(repository: InMemoryConfigRepository())
    await #expect(throws: (any Error).self) {
      try await service.minutes(
        for: RouteDef(name: "Fail", color: "#000000"), from: origin, to: destination)
    }
  }
}
