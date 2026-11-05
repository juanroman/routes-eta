import Domain
import Observation

@MainActor
@Observable
final class PlacePickerModel {
  private(set) var results: [NamedPoint] = []
  private(set) var failed = false
  private let service: any PlaceSearchService

  init(service: any PlaceSearchService) {
    self.service = service
  }

  func update(query: String) async {
    do {
      let found = try await service.search(query: query)
      guard !Task.isCancelled else { return }
      results = found
      failed = false
    } catch {
      guard !Task.isCancelled else { return }
      results = []
      failed = true
    }
  }
}
