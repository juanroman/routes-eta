import Domain

/// What the commute screen's lines depend on. `.task(id:)` reloads them (cancelling a load in
/// flight) whenever this changes: a place moved, a route's via points changed or the routes were
/// reordered, or "Retry" was pressed.
struct CommuteLinesKey: Hashable {
  var origin: NamedPoint?
  var destination: NamedPoint?
  var vias: [[LatLng]]
  var retries: Int

  init(commute: Commute, retries: Int) {
    origin = commute.origin
    destination = commute.destination
    vias = commute.routes.map(\.via)
    self.retries = retries
  }
}

/// What the selected route's ETA depends on: which route, and where it goes and through. Renaming
/// the commute or recoloring a route does not change it, so it does not ask Google again.
struct SelectedRouteETAKey: Hashable {
  var routeName: String?
  var via: [LatLng]
  var origin: NamedPoint?
  var destination: NamedPoint?

  init(commute: Commute, selected: String?) {
    let route = commute.routes.first { $0.name == selected }
    routeName = route?.name
    via = route?.via ?? []
    origin = commute.origin
    destination = commute.destination
  }
}
