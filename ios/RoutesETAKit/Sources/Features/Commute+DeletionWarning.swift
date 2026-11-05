import Domain

extension Commute {
  /// Shown in the delete-commute confirmation.
  var deletionWarning: String {
    let count = routes.count
    guard count > 0 else { return "This can't be undone." }
    return "Its \(count) \(count == 1 ? "route" : "routes") and schedule will be deleted too."
  }
}
