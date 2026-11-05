import Domain
import Foundation

/// Keeps Home/Work on this device as JSON in UserDefaults.
///
/// Stores the suite name rather than a `UserDefaults` instance because the
/// class isn't `Sendable`; opening it per call is cheap and thread-safe.
public struct UserDefaultsSavedPlacesRepository: SavedPlacesRepository {
  private let suiteName: String?
  private let key: String

  /// `suiteName == nil` uses the standard defaults.
  public init(suiteName: String? = nil, key: String = "savedPlaces.v1") {
    self.suiteName = suiteName
    self.key = key
  }

  private var defaults: UserDefaults { suiteName.flatMap(UserDefaults.init) ?? .standard }

  public func load() async throws -> SavedPlaces {
    guard let data = defaults.data(forKey: key) else { return SavedPlaces() }
    return try JSONDecoder().decode(SavedPlaces.self, from: data)
  }

  public func save(_ places: SavedPlaces) async throws {
    defaults.set(try JSONEncoder().encode(places), forKey: key)
  }
}
