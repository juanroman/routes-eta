import Foundation

/// Remembers a route's ETA for a couple of minutes, so selecting a route again right away (or
/// flipping between two) doesn't ask Google every time. Only the single-route ETA is cached:
/// the full report behind "Show ETAs" is always fresh, because pressing it means "right now".
///
/// In memory on purpose. A traffic-aware ETA is stale within minutes, so keeping it across
/// launches would only risk showing an old number. Failures are not cached.
public actor CachedETAService: ETAService {
  private struct Entry {
    var minutes: Int
    var fetchedAt: Date
  }

  private let wrapped: any ETAService
  private let timeToLive: TimeInterval
  private let now: @Sendable () -> Date
  private var entries: [RouteLineKey: Entry] = [:]

  public init(
    wrapping wrapped: any ETAService, timeToLive: TimeInterval = 120,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.wrapped = wrapped
    self.timeToLive = timeToLive
    self.now = now
  }

  public func run(commute: String) async throws -> ETAReport {
    try await wrapped.run(commute: commute)
  }

  public func minutes(
    for route: RouteDef, from origin: LatLng, to destination: LatLng
  ) async throws -> Int {
    let key = RouteLineKey(origin: origin, destination: destination, via: route.via)
    if let entry = entries[key], now().timeIntervalSince(entry.fetchedAt) < timeToLive {
      return entry.minutes
    }
    let minutes = try await wrapped.minutes(for: route, from: origin, to: destination)
    let stamp = now()
    entries = entries.filter { stamp.timeIntervalSince($0.value.fetchedAt) < timeToLive }
    entries[key] = Entry(minutes: minutes, fetchedAt: stamp)
    return minutes
  }
}
