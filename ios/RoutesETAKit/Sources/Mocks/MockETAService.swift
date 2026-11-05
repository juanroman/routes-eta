import Domain
import Foundation

/// Deterministic fake ETAs so UI states are reproducible.
///
/// - Minutes derive from the route name and via-point count (stable per route).
/// - A route whose name contains "fail" (case-insensitive) reports an error,
///   which gives the UI a partial-failure case to design against; if every route
///   fails the message is the all-failed text, like the real notification.
public struct MockETAService: ETAService {
  private let repository: any ConfigRepository

  public init(repository: any ConfigRepository) {
    self.repository = repository
  }

  public func run(commute name: String) async throws -> ETAReport {
    let config = try await repository.load()
    guard let commute = config.commutes.first(where: { $0.name == name }) else {
      throw ETAServiceError.unknownCommute(name)
    }
    let results = commute.routes.map(Self.eta(for:))
    let message: String
    if results.allSatisfy({ $0.minutes == nil }) {
      message = "\(name): Couldn't fetch ETAs"
    } else {
      let parts = results.map { "\($0.name) \($0.minutes.map(String.init) ?? "?")" }
      message = "\(name): " + parts.joined(separator: " · ")
    }
    return ETAReport(commute: name, message: message, results: results)
  }

  static func eta(for route: RouteDef) -> RouteETA {
    if route.name.localizedCaseInsensitiveContains("fail") {
      return RouteETA(name: route.name, minutes: nil, error: "Couldn't fetch this route")
    }
    let seed = route.name.utf8.reduce(0) { ($0 &* 31 &+ Int($1)) % 1000 }
    return RouteETA(name: route.name, minutes: 25 + seed % 30 + route.via.count * 3)
  }
}
