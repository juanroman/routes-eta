import Foundation
import Testing

@testable import Domain

struct CachedETAServiceTests {
  private struct Failure: Error {}

  /// A clock the test moves by hand.
  private final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 1_000_000)

    var now: Date { lock.withLock { current } }
    func advance(by seconds: TimeInterval) { lock.withLock { current += seconds } }
  }

  /// Counts how often Google would have been asked, and can be told to fail.
  private actor Source: ETAService {
    private(set) var minuteCalls = 0
    private(set) var reportCalls = 0
    private var failing: Bool

    init(failing: Bool = false) { self.failing = failing }

    func stopFailing() { failing = false }

    func run(commute: String) async throws -> ETAReport {
      reportCalls += 1
      return ETAReport(commute: commute, results: [])
    }

    func minutes(
      for route: RouteDef, from origin: LatLng, to destination: LatLng
    ) async throws -> Int {
      minuteCalls += 1
      if failing { throw Failure() }
      return 20 + route.via.count
    }
  }

  private let origin = LatLng(lat: 19.4, lng: -99.1)
  private let destination = LatLng(lat: 19.5, lng: -99.2)
  private let route = RouteDef(
    name: "City", color: "#2563eb", via: [LatLng(lat: 19.45, lng: -99.15)])

  private func service(
    _ source: Source, clock: Clock = Clock(), timeToLive: TimeInterval = 120
  ) -> CachedETAService {
    CachedETAService(wrapping: source, timeToLive: timeToLive, now: { clock.now })
  }

  @Test func theSameRouteWithinTheTimeToLiveIsAnsweredFromMemory() async throws {
    let source = Source()
    let clock = Clock()
    let cached = service(source, clock: clock)

    let first = try await cached.minutes(for: route, from: origin, to: destination)
    clock.advance(by: 119)
    let second = try await cached.minutes(for: route, from: origin, to: destination)

    #expect(first == 21 && second == 21)
    #expect(await source.minuteCalls == 1)
  }

  @Test func afterTheTimeToLiveItAsksAgain() async throws {
    let source = Source()
    let clock = Clock()
    let cached = service(source, clock: clock)

    _ = try await cached.minutes(for: route, from: origin, to: destination)
    clock.advance(by: 121)
    _ = try await cached.minutes(for: route, from: origin, to: destination)

    #expect(await source.minuteCalls == 2)
  }

  @Test func anotherRouteOrAnotherDirectionIsAnotherEntry() async throws {
    let source = Source()
    let cached = service(source)
    let direct = RouteDef(name: "Direct", color: "#dc2626")

    _ = try await cached.minutes(for: route, from: origin, to: destination)
    _ = try await cached.minutes(for: direct, from: origin, to: destination)
    _ = try await cached.minutes(for: route, from: destination, to: origin)

    #expect(await source.minuteCalls == 3)
  }

  @Test func aFailureIsPassedOnAndNotRemembered() async throws {
    let source = Source(failing: true)
    let cached = service(source)

    await #expect(throws: Failure.self) {
      try await cached.minutes(for: route, from: origin, to: destination)
    }
    await source.stopFailing()
    let retried = try await cached.minutes(for: route, from: origin, to: destination)

    #expect(retried == 21)
    #expect(await source.minuteCalls == 2)
  }

  /// "Show ETAs" means "right now", so the full report is never served from memory.
  @Test func theFullReportIsAlwaysAskedFresh() async throws {
    let source = Source()
    let cached = service(source)

    _ = try await cached.run(commute: "C")
    _ = try await cached.run(commute: "C")

    #expect(await source.reportCalls == 2)
    #expect(await source.minuteCalls == 0)
  }
}
