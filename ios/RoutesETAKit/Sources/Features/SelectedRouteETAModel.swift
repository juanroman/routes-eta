import Domain
import Foundation
import Observation

/// The ETA of the route selected on the commute screen. Callers run `load` from `.task(id:)`
/// keyed on the selection, so choosing another route cancels the request in flight (latest
/// wins) and a stale result is never shown. The service caches for a couple of minutes, so
/// selecting a route again right away costs nothing.
@MainActor
@Observable
final class SelectedRouteETAModel {
  enum State: Equatable {
    /// Nothing selected (or nothing to measure).
    case idle
    case loading
    case loaded(minutes: Int)
    case failed
  }

  private(set) var state: State = .idle
  private let service: any ETAService

  init(service: any ETAService) {
    self.service = service
  }

  func load(route: RouteDef?, origin: LatLng?, destination: LatLng?) async {
    // Assign only real changes: an @Observable property notifies its readers even when it is set
    // to the value it already has, and this screen's list must not be refreshed for nothing.
    guard let route, let origin, let destination else {
      set(.idle)
      return
    }
    set(.loading)
    do {
      let minutes = try await service.minutes(for: route, from: origin, to: destination)
      guard !Task.isCancelled else { return }
      set(.loaded(minutes: minutes))
    } catch is CancellationError {
      return
    } catch {
      guard !Task.isCancelled else { return }
      set(.failed)
    }
  }

  private func set(_ newState: State) {
    if state != newState { state = newState }
  }
}
