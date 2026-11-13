import Foundation

/// Which commute the Home view shows when it opens.
///
/// People open the app to check the commute that starts where they are, so the nearest origin
/// wins. If several origins are near, the one viewed most recently wins (not the nearest of
/// them): a person standing at home who always checks "Home to Work" should not get "Home to
/// Gym" because the gym's origin happens to be a few meters closer. With no location, or nothing
/// nearby, it falls back to what was viewed last, and then to the first commute in the list.
public struct HomeSelection: Equatable, Sendable {
  public enum Reason: Equatable, Sendable {
    /// The user is near this commute's origin; carries the origin's label ("Home").
    case near(originLabel: String)
    case lastViewed
    case firstInList
  }

  public var name: String
  public var reason: Reason

  public init(name: String, reason: Reason) {
    self.name = name
    self.reason = reason
  }

  /// How close the user must be to a commute's origin for it to count as "near".
  public static let defaultRadiusMeters = 1_000.0

  /// - Parameters:
  ///   - commutes: The commutes in list order.
  ///   - recent: Commute names, most recently viewed first. Names that no longer exist are
  ///     ignored, so a renamed or deleted commute needs no cleanup.
  ///   - here: The user's location, or nil when it is unknown or not allowed.
  /// - Returns: nil only when there are no commutes.
  public static func pick(
    commutes: [Commute], recent: [String], here: LatLng?,
    radiusMeters: Double = defaultRadiusMeters
  ) -> HomeSelection? {
    guard !commutes.isEmpty else { return nil }

    let nearby = here.flatMap {
      mostRecent(among: commutes, recent: recent, near: $0, radius: radiusMeters)
    }
    if let nearby { return nearby }
    let names = Set(commutes.map(\.name))
    if let name = recent.first(where: names.contains) {
      return HomeSelection(name: name, reason: .lastViewed)
    }
    return HomeSelection(name: commutes[0].name, reason: .firstInList)
  }

  /// A commute whose origin is near the user, with how recently it was viewed.
  private struct Candidate {
    var listIndex: Int
    /// Position in the history; never-viewed commutes share the worst rank.
    var rank: Int
    var name: String
    var originLabel: String
  }

  private static func mostRecent(
    among commutes: [Commute], recent: [String], near here: LatLng, radius: Double
  ) -> HomeSelection? {
    let candidates = commutes.enumerated().compactMap { index, commute -> Candidate? in
      guard let origin = commute.origin, origin.latLng.distance(to: here) <= radius else {
        return nil
      }
      return Candidate(
        listIndex: index, rank: recent.firstIndex(of: commute.name) ?? Int.max,
        name: commute.name, originLabel: origin.label)
    }
    // Equal ranks (never viewed) are ordered by the list.
    let best = candidates.min { ($0.rank, $0.listIndex) < ($1.rank, $1.listIndex) }
    return best.map { HomeSelection(name: $0.name, reason: .near(originLabel: $0.originLabel)) }
  }
}
