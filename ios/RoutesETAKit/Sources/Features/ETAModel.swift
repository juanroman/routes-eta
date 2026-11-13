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
  /// A pull-to-refresh is in flight and the previous report is still on screen (the view dims
  /// it). Never set by `load`, which replaces the report with a spinner instead.
  private(set) var isRefreshing = false
  private let service: any ETAService
  private let commuteName: String

  init(service: any ETAService, commuteName: String) {
    self.service = service
    self.commuteName = commuteName
  }

  /// Replaces whatever is shown with a spinner, then the fresh result: nothing old stays visible.
  func load() async {
    state = .loading
    await fetch()
  }

  /// Like `load`, but keeps the current report on screen (dimmed) until the new one arrives, as
  /// pull-to-refresh does. If nothing is loaded yet it is just `load`. A failure replaces the
  /// report with the error rather than leaving old numbers next to it.
  func refresh() async {
    guard case .loaded = state else {
      await load()
      return
    }
    isRefreshing = true
    defer { isRefreshing = false }
    await fetch()
  }

  private func fetch() async {
    do {
      let report = try await service.run(commute: commuteName)
      guard !Task.isCancelled else { return }
      state = .loaded(report, fetchedAt: Date())
    } catch is CancellationError {
      return
    } catch {
      guard !Task.isCancelled else { return }
      // Our own errors (missing key, offline, Google rejecting the request) carry a
      // message the user can act on; anything else gets the generic one.
      state = .failed((error as? LocalizedError)?.errorDescription ?? "Couldn't fetch ETAs.")
    }
  }
}
