import Observation
import SwiftUI

/// Where you can go from the commutes list. Hashable so it can drive a
/// `NavigationStack` path; carries ids, never copies of the data.
public enum AppRoute: Hashable, Sendable {
  case commute(CommuteEntry.ID)
  case routeEditor(commute: CommuteEntry.ID, routeName: String)
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
