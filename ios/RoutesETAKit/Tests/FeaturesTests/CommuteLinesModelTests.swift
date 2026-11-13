import Domain
import Testing

@testable import Features

@MainActor
struct CommuteLinesModelTests {
  private let origin = LatLng(lat: 19.4, lng: -99.1)
  private let destination = LatLng(lat: 19.5, lng: -99.2)
  private let stop = LatLng(lat: 19.45, lng: -99.15)

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

  private struct Failure: Error {}

  /// Draws straight lines. A route fails when its number of via points is in `failing`;
  /// while a `gate` is set, requests wait for it.
  private actor Service: RoutePreviewService {
    var failing: Set<Int> = []
    var gate: Gate?

    func configure(failing: Set<Int> = [], gate: Gate? = nil) {
      self.failing = failing
      self.gate = gate
    }

    func preview(origin: LatLng, destination: LatLng, via: [LatLng]) async throws -> RoutePreview {
      await gate?.wait()
      if failing.contains(via.count) { throw Failure() }
      return RoutePreview(
        distanceMeters: 1000 + via.count, polyline: [origin] + via + [destination])
    }
  }

  @Test func everyRoutesLineIsLoaded() async {
    let model = CommuteLinesModel(service: Service())
    await model.load(origin: origin, destination: destination, vias: [[], [stop]])

    #expect(model.lines.keys.sorted() == [0, 1])
    #expect(model.lines[1]?.count == 3)
    #expect(model.failedCount == 0)
    #expect(!model.isLoading)
  }

  @Test func aFailedRouteIsCountedAndTheOthersStillDraw() async {
    let service = Service()
    await service.configure(failing: [1])
    let model = CommuteLinesModel(service: service)
    await model.load(origin: origin, destination: destination, vias: [[], [stop], []])

    #expect(model.lines.keys.sorted() == [0, 2])
    #expect(model.failedCount == 1)
    #expect(!model.isLoading)
  }

  @Test func eachRoutesDistanceIsKeptByIndex() async {
    let service = Service()
    await service.configure(failing: [1])
    let model = CommuteLinesModel(service: service)
    await model.load(origin: origin, destination: destination, vias: [[], [stop], [stop, stop]])

    // The route that failed has no line and so no distance either.
    #expect(model.distances == [0: 1000, 2: 1002])
  }

  @Test func withoutBothEndpointsThereAreNoLines() async {
    let model = CommuteLinesModel(service: Service())
    await model.load(origin: origin, destination: destination, vias: [[]])
    #expect(!model.lines.isEmpty)

    await model.load(origin: origin, destination: nil, vias: [[]])
    #expect(model.lines.isEmpty)
    #expect(model.distances.isEmpty)
    #expect(model.failedCount == 0)
  }

  @Test func theOldLinesStayWhileTheNextLoadRuns() async {
    let service = Service()
    let model = CommuteLinesModel(service: service)
    await model.load(origin: origin, destination: destination, vias: [[]])

    let gate = Gate()
    await service.configure(gate: gate)
    let reload = Task { await model.load(origin: origin, destination: destination, vias: [[stop]]) }
    while !model.isLoading { await Task.yield() }

    #expect(model.lines[0]?.count == 2)  // still the old, two-point line
    await gate.open()
    await reload.value
    #expect(model.lines[0]?.count == 3)
  }

  @Test func aCancelledLoadNeverShowsItsResult() async {
    let service = Service()
    let gate = Gate()
    await service.configure(gate: gate)
    let model = CommuteLinesModel(service: service)

    let stale = Task { await model.load(origin: origin, destination: destination, vias: [[]]) }
    while !model.isLoading { await Task.yield() }
    stale.cancel()
    await gate.open()
    await stale.value

    #expect(model.lines.isEmpty)
  }
}
