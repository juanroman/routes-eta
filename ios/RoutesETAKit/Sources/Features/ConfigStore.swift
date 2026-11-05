import Domain
import Foundation
import Observation

/// The app's single source of truth for the config. Views read `entries`;
/// every mutation is validated first and then persisted through the repository,
/// so an invalid change never reaches the UI state (or the API, later).
@MainActor
@Observable
public final class ConfigStore {
  public enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
  }

  public private(set) var entries: [CommuteEntry] = []
  public private(set) var loadState: LoadState = .idle
  public private(set) var timezone = "America/Mexico_City"

  private let repository: any ConfigRepository

  public init(repository: any ConfigRepository) {
    self.repository = repository
  }

  public func entry(id: CommuteEntry.ID) -> CommuteEntry? {
    entries.first { $0.id == id }
  }

  public func load() async {
    loadState = .loading
    do {
      let config = try await repository.load()
      timezone = config.timezone
      entries = config.commutes.map { CommuteEntry(commute: $0) }
      loadState = .loaded
    } catch {
      loadState = .failed("Couldn't load your commutes.")
    }
  }

  /// Each mutator returns a user-facing error message, or `nil` on success.
  @discardableResult
  public func addCommute(named name: String) async -> String? {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    var updated = entries
    updated.append(CommuteEntry(commute: Commute(name: trimmed)))
    return await apply(updated)
  }

  @discardableResult
  public func renameCommute(id: CommuteEntry.ID, to name: String) async -> String? {
    guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
    var updated = entries
    updated[index].commute.name = name.trimmingCharacters(in: .whitespaces)
    return await apply(updated)
  }

  @discardableResult
  public func deleteCommute(id: CommuteEntry.ID) async -> String? {
    await apply(entries.filter { $0.id != id })
  }

  private func apply(_ updated: [CommuteEntry]) async -> String? {
    let config = Config(timezone: timezone, commutes: updated.map(\.commute))
    if let issue = config.validate().first { return issue.description }
    do {
      try await repository.save(config)
      entries = updated
      return nil
    } catch {
      return "Couldn't save your changes."
    }
  }
}
