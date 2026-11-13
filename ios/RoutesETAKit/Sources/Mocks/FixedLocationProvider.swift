import Domain

/// A user who is always exactly where you put them, for tests, previews and `-mock-services`.
///
/// Starts with whatever authorization it is given; `requestAuthorization` resolves
/// `.notDetermined` to `.authorized` or `.denied` as `grantsOnRequest` says, like the system
/// prompt would, and counts how many times it was asked.
public actor FixedLocationProvider: LocationProvider {
  private var current: LocationAuthorization
  private let location: LatLng?
  private let grantsOnRequest: Bool
  public private(set) var requestCount = 0

  public init(
    authorization: LocationAuthorization = .authorized, location: LatLng? = nil,
    grantsOnRequest: Bool = true
  ) {
    current = authorization
    self.location = location
    self.grantsOnRequest = grantsOnRequest
  }

  public func authorization() async -> LocationAuthorization { current }

  public func requestAuthorization() async -> LocationAuthorization {
    if current == .notDetermined {
      requestCount += 1
      current = grantsOnRequest ? .authorized : .denied
    }
    return current
  }

  public func currentLocation(timeout: Duration) async -> LatLng? {
    current == .authorized ? location : nil
  }
}

/// For when there is no way to know where the user is: nothing is ever asked, and the Home view
/// falls back to the commute viewed last.
public struct UnavailableLocationProvider: LocationProvider {
  public init() {}

  public func authorization() async -> LocationAuthorization { .denied }
  public func requestAuthorization() async -> LocationAuthorization { .denied }
  public func currentLocation(timeout: Duration) async -> LatLng? { nil }
}
