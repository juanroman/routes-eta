import Domain
import Foundation
import Observation

/// Fetches the ETAs for one commute and holds what the sheet shows.
@MainActor
@Observable
final class ETAModel {
  enum State: Equatable {
    case idle
    case loading
    case loaded(ETAReport, fetchedAt: Date)
    /// The request itself failed (as opposed to individual routes failing).
    case failed(String)
  }

  private(set) var state: State = .idle
  private let service: any ETAService
  private let commuteName: String

  init(service: any ETAService, commuteName: String) {
    self.service = service
    self.commuteName = commuteName
  }

  func load() async {
    state = .loading
    do {
      let report = try await service.run(commute: commuteName)
      guard !Task.isCancelled else { return }
      state = .loaded(report, fetchedAt: Date())
    } catch is CancellationError {
      return
    } catch {
      guard !Task.isCancelled else { return }
      state = .failed("Couldn't fetch ETAs.")
    }
  }
}
