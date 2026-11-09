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
    await updateCommute(id: id) { $0.name = name.trimmingCharacters(in: .whitespaces) }
  }

  /// Applies `mutate` to one commute, validating and persisting the result.
  /// The single write path for the editors, so every edit gets the same checks.
  @discardableResult
  public func updateCommute(
    id: CommuteEntry.ID, _ mutate: (inout Commute) -> Void
  ) async -> String? {
    guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
    var updated = entries
    mutate(&updated[index].commute)
    return await apply(updated)
  }

  /// Appends a default-named route. Returns its index, or the error message.
  public func addRoute(to id: CommuteEntry.ID) async -> Result<Int, ConfigStoreError> {
    var index = 0
    if let message = await updateCommute(id: id, { index = $0.addRoute() }) {
      return .failure(ConfigStoreError(message: message))
    }
    return .success(index)
  }

  @discardableResult
  public func deleteRoute(in id: CommuteEntry.ID, at index: Int) async -> String? {
    await updateCommute(id: id) {
      if $0.routes.indices.contains(index) { $0.routes.remove(at: index) }
    }
  }

  /// Reorders the commutes. The order is the array order in the config, which the
  /// API and the web builder read too, so no extra field is needed.
  @discardableResult
  public func moveCommute(from source: IndexSet, to destination: Int) async -> String? {
    var updated = entries
    updated.move(fromOffsets: source, toOffset: destination)
    return await apply(updated)
  }

  /// Reorders a commute's routes. Routes are addressed by index (`AppRoute.routeEditor`),
  /// which is safe because reordering only happens on the list screen, never with an
  /// editor on the navigation stack.
  @discardableResult
  public func moveRoute(
    in id: CommuteEntry.ID, from source: IndexSet, to destination: Int
  ) async -> String? {
    await updateCommute(id: id) { $0.routes.move(fromOffsets: source, toOffset: destination) }
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

public struct ConfigStoreError: Error, Equatable, Sendable {
  public let message: String
}
