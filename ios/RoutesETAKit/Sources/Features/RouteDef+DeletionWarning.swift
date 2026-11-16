import Domain

extension RouteDef {
  /// Shown in the delete-route confirmation.
  var deletionWarning: String {
    switch via.count {
    case 0: String(localized: "This can't be undone.")
    case 1: String(localized: "Its 1 via point will be deleted too.")
    default: String(localized: "Its \(via.count) via points will be deleted too.")
    }
  }
}
