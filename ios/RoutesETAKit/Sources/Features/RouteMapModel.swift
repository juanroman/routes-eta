import Domain
import Foundation
import Observation

/// Holds the drawn polyline for the route being edited. Previews are fetched
/// from the `RoutePreviewService`; callers run `load` from `.task(id:)`, so a
/// newer edit cancels an older request (latest wins) and a stale result is
/// never shown.
@MainActor
@Observable
final class RouteMapModel {
  enum Status: Equatable {
    case idle
    case loading
    case loaded
    case failed
  }

  private(set) var polyline: [LatLng] = []
  private(set) var distanceMeters: Int?
  private(set) var status: Status = .idle
  /// Why the last request failed, in words for the user; nil unless `status == .failed`.
  private(set) var failureMessage: String?
  private let service: any RoutePreviewService

  init(service: any RoutePreviewService) {
    self.service = service
  }

  /// The previous polyline stays on screen while a new one loads or if it fails,
  /// so the map doesn't flash empty after every edit.
  func load(origin: LatLng, destination: LatLng, via: [LatLng]) async {
    status = .loading
    failureMessage = nil
    do {
      let preview = try await service.preview(origin: origin, destination: destination, via: via)
      guard !Task.isCancelled else { return }
      polyline = preview.polyline
      distanceMeters = preview.distanceMeters
      status = .loaded
    } catch is CancellationError {
      return
    } catch {
      guard !Task.isCancelled else { return }
      status = .failed
      failureMessage = (error as? LocalizedError)?.errorDescription
    }
  }
}
