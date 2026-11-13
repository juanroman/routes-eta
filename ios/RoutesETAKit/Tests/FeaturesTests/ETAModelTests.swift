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

/// Holds `run` until released, so a test can look at the model while a request is in flight.
actor GatedETAService: ETAService {
  private var isOpen = true
  private var waiters: [CheckedContinuation<Void, Never>] = []
  private(set) var calls = 0
  private let failing: Bool

  init(failing: Bool = false) {
    self.failing = failing
  }

  func close() { isOpen = false }

  func release() {
    isOpen = true
    for waiter in waiters { waiter.resume() }
    waiters = []
  }

  func run(commute: String) async throws -> ETAReport {
    calls += 1
    let call = calls
    if !isOpen { await withCheckedContinuation { waiters.append($0) } }
    if failing && call > 1 { throw ETAFailureMessageTests.Explaining() }
    return ETAReport(
      commute: commute, message: "", results: [RouteETA(name: "R", minutes: call * 10)])
  }

  func minutes(
    for route: RouteDef, from origin: LatLng, to destination: LatLng
  ) async throws -> Int { 1 }
}

@MainActor
struct ETAModelRefreshTests {
  private func minutes(_ model: ETAModel) -> Int? {
    guard case .loaded(let report, _) = model.state else { return nil }
    return report.results.first?.minutes
  }

  private func waitForCalls(_ count: Int, on service: GatedETAService) async {
    while await service.calls < count { await Task.yield() }
  }

  @Test func refreshKeepsTheOldNumbersUntilTheNewOnesArrive() async {
    let service = GatedETAService()
    let model = ETAModel(service: service, commuteName: "C")
    await model.load()
    #expect(minutes(model) == 10)

    await service.close()
    let refreshing = Task { await model.refresh() }
    await waitForCalls(2, on: service)
    #expect(model.isRefreshing)
    #expect(minutes(model) == 10)

    await service.release()
    await refreshing.value
    #expect(!model.isRefreshing)
    #expect(minutes(model) == 20)
  }

  @Test func loadReplacesTheNumbersWithASpinner() async {
    let service = GatedETAService()
    let model = ETAModel(service: service, commuteName: "C")
    await model.load()

    await service.close()
    let loading = Task { await model.load() }
    await waitForCalls(2, on: service)
    #expect(model.state == .loading)
    #expect(!model.isRefreshing)

    await service.release()
    await loading.value
    #expect(minutes(model) == 20)
  }

  @Test func refreshingBeforeAnythingLoadedIsJustALoad() async {
    let model = ETAModel(service: GatedETAService(), commuteName: "C")
    await model.refresh()
    #expect(minutes(model) == 10)
    #expect(!model.isRefreshing)
  }

  @Test func aFailedRefreshReplacesTheOldNumbersWithTheError() async {
    let model = ETAModel(service: GatedETAService(failing: true), commuteName: "C")
    await model.load()
    #expect(minutes(model) == 10)

    await model.refresh()
    #expect(model.state == .failed("Add your Google API key."))
    #expect(!model.isRefreshing)
  }
}
