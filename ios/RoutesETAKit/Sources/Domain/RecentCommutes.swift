/// Where the names of the commutes the user has viewed are kept (on the device), most recent
/// first. It is how the Home view breaks a tie between commutes that start near the user, and
/// what it falls back to when it doesn't know where the user is.
///
/// Names rather than `CommuteEntry.id`: that id is regenerated on every launch, while the name is
/// the commute's identity in the config. A renamed or deleted commute simply stops matching
/// (`HomeSelection` ignores names that no longer exist), so nothing needs cleaning up.
public protocol RecentCommutesRepository: Sendable {
  func load() async throws -> [String]
  func save(_ names: [String]) async throws
}

public enum RecentCommutes {
  /// How many names are remembered. Stale ones age out instead of piling up.
  public static let limit = 10

  /// `names` with `name` moved to the front: viewing a commute again promotes it, never
  /// duplicates it. A blank name is ignored.
  public static func touch(_ name: String, in names: [String], limit: Int = limit) -> [String] {
    guard !name.isEmpty else { return names }
    return Array(([name] + names.filter { $0 != name }).prefix(limit))
  }
}
