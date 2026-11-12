import Testing

@testable import Domain

struct CachedRoutePreviewServiceTests {
  private actor Cache: RouteLineCache {
    private var lines: [RouteLineKey: RoutePreview] = [:]
    func line(for key: RouteLineKey) async -> RoutePreview? { lines[key] }
    func store(_ preview: RoutePreview, for key: RouteLineKey) async { lines[key] = preview }
  }

  private struct Failure: Error {}

  /// Counts how often Google would have been asked, and can be told to fail.
  private actor Source: RoutePreviewService {
    private(set) var calls = 0
    private var failing: Bool

    init(failing: Bool = false) { self.failing = failing }

    func stopFailing() { failing = false }

    func preview(origin: LatLng, destination: LatLng, via: [LatLng]) async throws -> RoutePreview {
      calls += 1
      if failing { throw Failure() }
      return RoutePreview(
        distanceMeters: 1000 + via.count, polyline: [origin] + via + [destination])
    }
  }

  private let origin = LatLng(lat: 19.4, lng: -99.1)
  private let destination = LatLng(lat: 19.5, lng: -99.2)
  private let via = [LatLng(lat: 19.45, lng: -99.15)]

  @Test func theSecondRequestForTheSameRouteIsAnsweredFromTheCache() async throws {
    let source = Source()
    let service = CachedRoutePreviewService(wrapping: source, cache: Cache())

    let first = try await service.preview(origin: origin, destination: destination, via: via)
    let second = try await service.preview(origin: origin, destination: destination, via: via)

    #expect(second == first)
    #expect(await source.calls == 1)
  }

  @Test func changingTheViaPointsAsksAgain() async throws {
    let source = Source()
    let service = CachedRoutePreviewService(wrapping: source, cache: Cache())

    _ = try await service.preview(origin: origin, destination: destination, via: via)
    let moved = try await service.preview(
      origin: origin, destination: destination, via: [LatLng(lat: 19.46, lng: -99.16)])

    #expect(await source.calls == 2)
    #expect(moved.polyline[1] == LatLng(lat: 19.46, lng: -99.16))
  }

  @Test func theOrderOfViaPointsMatters() async throws {
    let source = Source()
    let service = CachedRoutePreviewService(wrapping: source, cache: Cache())
    let first = LatLng(lat: 19.42, lng: -99.12)
    let second = LatLng(lat: 19.48, lng: -99.18)

    _ = try await service.preview(origin: origin, destination: destination, via: [first, second])
    _ = try await service.preview(origin: origin, destination: destination, via: [second, first])

    #expect(await source.calls == 2)
  }

  @Test func theOtherDirectionIsADifferentRoute() async throws {
    let source = Source()
    let service = CachedRoutePreviewService(wrapping: source, cache: Cache())

    _ = try await service.preview(origin: origin, destination: destination, via: [])
    _ = try await service.preview(origin: destination, destination: origin, via: [])

    #expect(await source.calls == 2)
  }

  @Test func aFailureIsPassedOnAndNotRemembered() async throws {
    let source = Source(failing: true)
    let service = CachedRoutePreviewService(wrapping: source, cache: Cache())

    await #expect(throws: Failure.self) {
      try await service.preview(origin: origin, destination: destination, via: via)
    }
    await source.stopFailing()
    let retried = try await service.preview(origin: origin, destination: destination, via: via)

    #expect(retried.distanceMeters == 1001)
    #expect(await source.calls == 2)
  }
}
