import Domain
import Foundation
import Mocks
import Testing

@testable import Features

@MainActor
struct SelectedRouteETAModelTests {
  private let origin = LatLng(lat: 19.4, lng: -99.1)
  private let destination = LatLng(lat: 19.5, lng: -99.2)
  private let city = RouteDef(name: "City", color: "#2563eb")
  private let service = MockETAService(repository: InMemoryConfigRepository())

  private actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
      if isOpen { return }
      await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
      isOpen = true
      for waiter in waiters { waiter.resume() }
      waiters = []
    }
  }

  /// Answers 33 minutes once its gate is opened.
  private struct Gated: ETAService {
    let gate: Gate
    func run(commute: String) async throws -> ETAReport { ETAReport(commute: commute, results: []) }
    func minutes(
      for route: RouteDef, from origin: LatLng, to destination: LatLng
    ) async throws -> Int {
      await gate.wait()
      return 33
    }
  }

  @Test func startsIdle() {
    #expect(SelectedRouteETAModel(service: service).state == .idle)
  }

  @Test func withNothingSelectedOrNoPlacesThereIsNothingToFetch() async {
    let model = SelectedRouteETAModel(service: service)
    await model.load(route: nil, origin: origin, destination: destination)
    #expect(model.state == .idle)

    await model.load(route: city, origin: nil, destination: destination)
    #expect(model.state == .idle)
  }

  @Test func loadsTheSelectedRoutesMinutes() async throws {
    let expected = try await service.minutes(for: city, from: origin, to: destination)
    let model = SelectedRouteETAModel(service: service)

    await model.load(route: city, origin: origin, destination: destination)

    #expect(model.state == .loaded(minutes: expected))
  }

  @Test func aRouteThatCannotBeFetchedFails() async {
    let model = SelectedRouteETAModel(service: service)
    await model.load(
      route: RouteDef(name: "Fail", color: "#000000"), origin: origin, destination: destination)
    #expect(model.state == .failed)
  }

  @Test func clearingTheSelectionGoesBackToIdle() async {
    let model = SelectedRouteETAModel(service: service)
    await model.load(route: city, origin: origin, destination: destination)
    await model.load(route: nil, origin: origin, destination: destination)
    #expect(model.state == .idle)
  }

  @Test func aCancelledLoadNeverShowsItsResult() async {
    let gate = Gate()
    let model = SelectedRouteETAModel(service: Gated(gate: gate))

    let stale = Task { await model.load(route: city, origin: origin, destination: destination) }
    while model.state != .loading { await Task.yield() }
    stale.cancel()
    await gate.open()
    await stale.value

    #expect(model.state == .loading)  // the newer load, if any, owns the state; never the stale 33
  }
}
