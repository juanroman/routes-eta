import Observation
import SwiftUI

/// Where you can go from the commutes list. Hashable so it can drive a
/// `NavigationStack` path; carries ids, never copies of the data.
public enum AppRoute: Hashable, Sendable {
  case commute(CommuteEntry.ID)
  /// Index, not name: the editor renames routes, which would invalidate a name key.
  case routeEditor(commute: CommuteEntry.ID, route: Int)
  case scheduleEditor(commute: CommuteEntry.ID)
}

@MainActor
@Observable
public final class AppRouter {
  public var path: [AppRoute] = []

  public init() {}

  public func push(_ route: AppRoute) { path.append(route) }

  public func popToRoot() { path.removeAll() }
}
