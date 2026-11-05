extension ETAReport {
  /// Every route failed (the notification then reads "Couldn't fetch ETAs").
  public var allFailed: Bool {
    !results.isEmpty && results.allSatisfy { $0.minutes == nil }
  }

  /// Name of the quickest route that has an ETA; nil if none do.
  public var fastestRouteName: String? {
    results
      .compactMap { result in result.minutes.map { (name: result.name, minutes: $0) } }
      .min { $0.minutes < $1.minutes }?
      .name
  }
}

extension Commute {
  /// Why ETAs can't be fetched yet, or nil when the commute is ready.
  public var etaBlocker: String? {
    if origin == nil || destination == nil { return "Set origin and destination first" }
    if routes.isEmpty { return "Add a route first" }
    return nil
  }
}
