import CoreLocation
import Domain
import Foundation

/// `LocationProvider` backed by CoreLocation, asking only for "While Using the App".
///
/// Approximate is plenty: the Home view only asks "is the user within about a kilometer of this
/// origin". A recent last-known location is used when there is one, so opening the app doesn't
/// wait for a GPS fix.
@MainActor
public final class CoreLocationProvider: NSObject, LocationProvider, CLLocationManagerDelegate {
  /// How old a last-known location may be and still count as "where the user is".
  static let maximumAge: TimeInterval = 120
  /// A location less precise than this can't tell which origin the user is near.
  static let maximumUncertaintyMeters: CLLocationAccuracy = 1_000

  private let manager = CLLocationManager()
  private var waiting: [CheckedContinuation<LocationAuthorization, Never>] = []

  public override init() {
    super.init()
    manager.delegate = self
  }

  public func authorization() async -> LocationAuthorization {
    Self.authorization(from: manager.authorizationStatus)
  }

  public func requestAuthorization() async -> LocationAuthorization {
    let current = Self.authorization(from: manager.authorizationStatus)
    guard current == .notDetermined else { return current }
    return await withCheckedContinuation { continuation in
      waiting.append(continuation)
      manager.requestWhenInUseAuthorization()
    }
  }

  public func currentLocation(timeout: Duration) async -> LatLng? {
    guard Self.authorization(from: manager.authorizationStatus) == .authorized else { return nil }
    if let last = manager.location, Self.isUsable(last, now: Date()) {
      return LatLng(lat: last.coordinate.latitude, lng: last.coordinate.longitude)
    }
    return await withTimeout(timeout) { await Self.firstFix() }
  }

  // MARK: - Delegate

  /// Called once when the delegate is set (with the current status) and again after the user
  /// answers the prompt, so only a decided status settles the waiting callers.
  public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status = manager.authorizationStatus
    Task { @MainActor in self.settle(for: status) }
  }

  private func settle(for status: CLAuthorizationStatus) {
    let result = Self.authorization(from: status)
    guard result != .notDetermined else { return }
    let continuations = waiting
    waiting = []
    for continuation in continuations { continuation.resume(returning: result) }
  }

  // MARK: - Pure pieces, kept apart so they can be tested without a device

  static func authorization(from status: CLAuthorizationStatus) -> LocationAuthorization {
    switch status {
    case .notDetermined: .notDetermined
    case .authorizedWhenInUse, .authorizedAlways: .authorized
    case .denied, .restricted: .denied
    @unknown default: .denied
    }
  }

  static func isUsable(_ location: CLLocation, now: Date) -> Bool {
    location.horizontalAccuracy >= 0
      && location.horizontalAccuracy <= maximumUncertaintyMeters
      && abs(now.timeIntervalSince(location.timestamp)) <= maximumAge
  }

  /// The first location CoreLocation delivers. Ends when cancelled (the timeout) or when the
  /// stream fails, in which case there is simply no location. No explicit `CLServiceSession`:
  /// the caller has already checked that the user said yes, and without one the system keeps
  /// the app's authorization for the duration of the update stream.
  private nonisolated static func firstFix() async -> LatLng? {
    do {
      for try await update in CLLocationUpdate.liveUpdates() {
        if let location = update.location {
          return LatLng(lat: location.coordinate.latitude, lng: location.coordinate.longitude)
        }
      }
    } catch {
      return nil
    }
    return nil
  }
}
