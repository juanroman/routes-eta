import Domain
import Foundation

/// Keeps the recently viewed commute names on this device, in UserDefaults.
///
/// Only names are stored. ETAs never are: a traffic-aware ETA is stale within minutes, and
/// Google's terms don't allow keeping it.
///
/// Stores the suite name rather than a `UserDefaults` instance because the class isn't
/// `Sendable`; opening it per call is cheap and thread-safe.
public struct UserDefaultsRecentCommutesRepository: RecentCommutesRepository {
  private let suiteName: String?
  private let key: String

  /// `suiteName == nil` uses the standard defaults.
  public init(suiteName: String? = nil, key: String = "recentCommutes.v1") {
    self.suiteName = suiteName
    self.key = key
  }

  private var defaults: UserDefaults { suiteName.flatMap(UserDefaults.init) ?? .standard }

  public func load() async throws -> [String] {
    defaults.stringArray(forKey: key) ?? []
  }

  public func save(_ names: [String]) async throws {
    defaults.set(names, forKey: key)
  }
}
