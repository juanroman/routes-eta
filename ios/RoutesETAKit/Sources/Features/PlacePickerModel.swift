import Domain
import Observation

@MainActor
@Observable
final class PlacePickerModel {
  private(set) var suggestions: [PlaceSuggestion] = []
  private(set) var failed = false
  private(set) var resolveFailed = false
  private let service: any PlaceSearchService

  init(service: any PlaceSearchService) {
    self.service = service
  }

  func update(query: String) async {
    do {
      let found = try await service.suggestions(for: query)
      guard !Task.isCancelled else { return }
      suggestions = found
      failed = false
    } catch is CancellationError {
      return
    } catch {
      guard !Task.isCancelled else { return }
      suggestions = []
      failed = true
    }
  }

  /// Coordinates for a chosen suggestion, or nil (with `resolveFailed` set).
  func resolve(_ suggestion: PlaceSuggestion) async -> NamedPoint? {
    do {
      let point = try await service.resolve(suggestion)
      resolveFailed = false
      return point
    } catch {
      resolveFailed = true
      return nil
    }
  }
}
