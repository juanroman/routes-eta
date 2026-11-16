import Domain

extension Commute {
  /// Shown in the delete-commute confirmation.
  var deletionWarning: String {
    let count = routes.count
    guard count > 0 else { return String(localized: "This can't be undone.") }
    // One string per case rather than plural variations: the plain English key keeps working
    // where there is no catalog (package tests, previews), and Spanish has no other forms.
    return count == 1
      ? String(localized: "Its 1 route will be deleted too.")
      : String(localized: "Its \(count) routes will be deleted too.")
  }
}
