public enum LocationAuthorization: Equatable, Sendable {
  /// The user hasn't been asked yet.
  case notDetermined
  /// Refused, or restricted (parental controls, an MDM profile): either way, don't ask again.
  case denied
  case authorized
  /// Allowed, but the user turned Precise Location off, so iOS only reports an area several
  /// kilometers wide. That can't tell which origin is nearby, so it counts as having no location.
  case reducedAccuracy
}

/// Where the user is, so the Home view can show the commute that starts nearby.
///
/// The location is only ever compared on the device with the commutes' origins. It must never be
/// sent anywhere, in particular not to Google: Routes requests carry the commute's own places,
/// and Google's terms require consent before obtaining an end user's location at all.
public protocol LocationProvider: Sendable {
  func authorization() async -> LocationAuthorization

  /// Asks the user for permission if they haven't been asked yet, and returns the answer. Does
  /// nothing (and returns the current answer) once they have decided.
  func requestAuthorization() async -> LocationAuthorization

  /// A recent fix, or nil if location isn't allowed or none arrived within `timeout`. The Home
  /// view waits for this before it can choose a commute, so it is bounded: a slow fix must not
  /// keep the ETAs from loading.
  func currentLocation(timeout: Duration) async -> LatLng?
}
