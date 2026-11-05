import Domain

extension RouteDef {
  /// Shown in the delete-route confirmation.
  var deletionWarning: String {
    via.isEmpty
      ? "This can't be undone."
      : "Its \(via.count) via \(via.count == 1 ? "point" : "points") will be deleted too."
  }
}
