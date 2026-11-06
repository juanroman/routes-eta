import Domain
import Foundation

/// `RoutePreviewService` backed by Google's Routes API: the road-following line
/// the editor draws through the route's via points.
public struct GoogleRoutePreviewService: RoutePreviewService {
  private let client: GoogleRoutesClient

  public init(client: GoogleRoutesClient) {
    self.client = client
  }

  public func preview(
    origin: LatLng, destination: LatLng, via: [LatLng]
  ) async throws -> RoutePreview {
    try await client.previewRoute(origin: origin, destination: destination, via: via)
  }
}

/// `ETAService` backed by Google's Routes API: one traffic-aware request per
/// route, run concurrently. Like the Pi's checker, a route that fails never
/// prevents the others from being reported.
public struct GoogleETAService: ETAService {
  private let client: GoogleRoutesClient
  private let repository: any ConfigRepository

  public init(client: GoogleRoutesClient, repository: any ConfigRepository) {
    self.client = client
    self.repository = repository
  }

  public func run(commute name: String) async throws -> ETAReport {
    let config = try await repository.load()
    guard let commute = config.commutes.first(where: { $0.name == name }) else {
      throw ETAServiceError.unknownCommute(name)
    }
    if let blocker = commute.etaBlocker { throw ETAServiceError.notReady(blocker) }
    guard let origin = commute.origin?.latLng, let destination = commute.destination?.latLng else {
      throw ETAServiceError.notReady("Set origin and destination first")
    }
    // Without a key every route would fail identically; say so once, up front.
    try client.validateKey()

    let client = client
    let results = await withTaskGroup(of: (Int, RouteETA).self) { group in
      for (index, route) in commute.routes.enumerated() {
        group.addTask {
          do {
            let seconds = try await client.routeDurationSeconds(
              origin: origin, destination: destination, via: route.via)
            return (
              index, RouteETA(name: route.name, minutes: RouteETA.minutes(fromSeconds: seconds))
            )
          } catch {
            let message = error.localizedDescription
            return (index, RouteETA(name: route.name, minutes: nil, error: message))
          }
        }
      }
      var ordered = [RouteETA?](repeating: nil, count: commute.routes.count)
      for await (index, result) in group { ordered[index] = result }
      return ordered.compactMap { $0 }
    }
    return ETAReport(commute: name, results: results)
  }
}
