import Observation
import SwiftUI

/// Where you can go from the Home view. Hashable so it can drive a
/// `NavigationStack` path; carries ids, never copies of the data.
public enum AppRoute: Hashable, Sendable {
  /// The list for adding, renaming, reordering and deleting commutes; Home's "Edit".
  case commutes
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
