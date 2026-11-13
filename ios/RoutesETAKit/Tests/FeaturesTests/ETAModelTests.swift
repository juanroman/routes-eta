import Domain
import Foundation
import Mocks
import Testing

@testable import Features

@MainActor
struct ETAModelTests {
  @Test func startsIdle() {
    let model = ETAModel(
      service: MockETAService(repository: InMemoryConfigRepository()), commuteName: "Work to Home")
    #expect(model.state == .idle)
  }

  @Test func loadsRoutesInConfigOrder() async throws {
    let model = ETAModel(
      service: MockETAService(repository: InMemoryConfigRepository()), commuteName: "Work to Home")
    await model.load()
    guard case .loaded(let report, _) = model.state else {
      Issue.record("expected loaded, got \(model.state)")
      return
    }
    #expect(report.results.map(\.name) == ["City", "Mordor"])
    #expect(report.fastestRouteName != nil)
  }

  @Test func partialFailureStillLoads() async throws {
    let config = Config(commutes: [
      Commute(
        name: "C",
        routes: [
          RouteDef(name: "Good", color: "#000000"), RouteDef(name: "Fail", color: "#111111"),
        ]
      )
    ])
    let model = ETAModel(
      service: MockETAService(repository: InMemoryConfigRepository(initial: config)),
      commuteName: "C")
    await model.load()
    guard case .loaded(let report, _) = model.state else {
      Issue.record("expected loaded, got \(model.state)")
      return
    }
    #expect(report.allFailed == false)
    #expect(report.results[1].minutes == nil)
  }

  @Test func allRoutesFailingIsAReportNotAnError() async throws {
    let config = Config(commutes: [
      Commute(name: "C", routes: [RouteDef(name: "Fail", color: "#111111")])
    ])
    let model = ETAModel(
      service: MockETAService(repository: InMemoryConfigRepository(initial: config)),
      commuteName: "C")
    await model.load()
    guard case .loaded(let report, _) = model.state else {
      Issue.record("expected loaded, got \(model.state)")
      return
    }
    #expect(report.allFailed)
  }

  @Test func requestFailureBecomesFailedState() async {
    let model = ETAModel(
      service: MockETAService(repository: InMemoryConfigRepository()), commuteName: "Nope")
    await model.load()
    #expect(model.state == .failed("Couldn't fetch ETAs."))
  }

  @Test func retryAfterFailureCanSucceed() async {
    let repository = InMemoryConfigRepository(initial: Config())
    let model = ETAModel(service: MockETAService(repository: repository), commuteName: "C")
    await model.load()
    #expect(model.state == .failed("Couldn't fetch ETAs."))

    try? await repository.save(
      Config(commutes: [Commute(name: "C", routes: [RouteDef(name: "R", color: "#000000")])]))
    await model.load()
    if case .loaded = model.state {} else { Issue.record("expected loaded after retry") }
  }
}

@MainActor
struct ETAFailureMessageTests {
  struct Explaining: LocalizedError {
    var errorDescription: String? { "Add your Google API key." }
  }

  struct Failing: ETAService {
    let error: any Error
    func run(commute: String) async throws -> ETAReport { throw error }
    func minutes(
      for route: RouteDef, from origin: LatLng, to destination: LatLng
    ) async throws -> Int { throw error }
  }

  @Test func actionableErrorsReachTheSheet() async {
    let model = ETAModel(service: Failing(error: Explaining()), commuteName: "C")
    await model.load()
    #expect(model.state == .failed("Add your Google API key."))
  }

  @Test func otherErrorsGetTheGenericMessage() async {
    let model = ETAModel(
      service: Failing(error: ETAServiceError.unknownCommute("C")), commuteName: "C")
    await model.load()
    #expect(model.state == .failed("Couldn't fetch ETAs."))
  }
}
