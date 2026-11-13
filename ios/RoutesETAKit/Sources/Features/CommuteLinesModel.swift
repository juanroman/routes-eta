import Domain
import Foundation
import Observation

/// The drawn lines of every route of one commute. Callers run `load` from
/// `.task(id:)`, so a newer edit cancels an older request (latest wins) and a stale
/// result is never shown. Lines come through the (cached) `RoutePreviewService`, so
/// routes already seen draw without a Google call.
@MainActor
@Observable
final class CommuteLinesModel {
  /// By route index.
  private(set) var lines: [Int: [LatLng]] = [:]
  /// Routes whose line couldn't be drawn in the last load.
  private(set) var failedCount = 0
  private(set) var isLoading = false
  private let service: any RoutePreviewService

  init(service: any RoutePreviewService) {
    self.service = service
  }

  /// Without both endpoints there is nothing to draw. The previous lines stay on
  /// screen while a new load runs or if it fails, so the map doesn't flash empty.
  func load(origin: LatLng?, destination: LatLng?, vias: [[LatLng]]) async {
    guard let origin, let destination else {
      lines = [:]
      failedCount = 0
      isLoading = false
      return
    }
    isLoading = true
    let service = service
    let loaded = await withTaskGroup(of: (Int, [LatLng])?.self) { group in
      for (index, via) in vias.enumerated() {
        group.addTask {
          guard
            let preview = try? await service.preview(
              origin: origin, destination: destination, via: via),
            preview.polyline.count > 1
          else { return nil }
          return (index, preview.polyline)
        }
      }
      var result: [Int: [LatLng]] = [:]
      for await entry in group {
        if let entry { result[entry.0] = entry.1 }
      }
      return result
    }
    // A newer load owns the state now (it already set `isLoading`); leave it be.
    guard !Task.isCancelled else { return }
    lines = loaded
    failedCount = vias.count - loaded.count
    isLoading = false
  }
}
