import Domain
import Foundation

/// Keeps "the user said Not now" on this device, in UserDefaults. See
/// `UserDefaultsRecentCommutesRepository` for why it stores the suite name.
public struct UserDefaultsLocationPromptRepository: LocationPromptRepository {
  private let suiteName: String?
  private let key: String

  /// `suiteName == nil` uses the standard defaults.
  public init(suiteName: String? = nil, key: String = "locationPromptDeclined.v1") {
    self.suiteName = suiteName
    self.key = key
  }

  private var defaults: UserDefaults { suiteName.flatMap(UserDefaults.init) ?? .standard }

  public func wasDeclined() async -> Bool { defaults.bool(forKey: key) }

  public func markDeclined() async { defaults.set(true, forKey: key) }
}
