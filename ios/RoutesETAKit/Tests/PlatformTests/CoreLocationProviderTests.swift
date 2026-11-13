import CoreLocation
import Domain
import Foundation
import Testing

@testable import Platform

struct CoreLocationProviderTests {
  @Test @MainActor func everySystemStatusMapsToOneOfOurs() {
    func map(_ status: CLAuthorizationStatus, _ accuracy: CLAccuracyAuthorization = .fullAccuracy)
      -> LocationAuthorization
    {
      CoreLocationProvider.authorization(from: status, accuracy: accuracy)
    }
    #expect(map(.notDetermined) == .notDetermined)
    #expect(map(.authorizedAlways) == .authorized)
    #expect(map(.denied) == .denied)
    #expect(map(.restricted) == .denied)
    #if os(iOS)
      // Doesn't exist on macOS, where `swift test` runs; the app only runs on iOS.
      #expect(map(.authorizedWhenInUse) == .authorized)
    #endif
  }

  @Test @MainActor func approximateLocationIsItsOwnState() {
    let map = CoreLocationProvider.authorization(from:accuracy:)
    #expect(map(.authorizedAlways, .reducedAccuracy) == .reducedAccuracy)
    #expect(map(.authorizedAlways, .fullAccuracy) == .authorized)
    // Accuracy only matters once the user has allowed location at all.
    #expect(map(.denied, .reducedAccuracy) == .denied)
    #expect(map(.notDetermined, .reducedAccuracy) == .notDetermined)
  }

  private let now = Date(timeIntervalSince1970: 1_000_000)

  private func location(accuracy: Double, secondsOld: Double) -> CLLocation {
    CLLocation(
      coordinate: CLLocationCoordinate2D(latitude: 19.43, longitude: -99.13),
      altitude: 0, horizontalAccuracy: accuracy, verticalAccuracy: -1,
      timestamp: now.addingTimeInterval(-secondsOld))
  }

  @Test @MainActor func aRecentPreciseLocationIsUsable() {
    #expect(CoreLocationProvider.isUsable(location(accuracy: 65, secondsOld: 10), now: now))
  }

  @Test @MainActor func anOldLocationIsNotUsable() {
    #expect(!CoreLocationProvider.isUsable(location(accuracy: 65, secondsOld: 121), now: now))
    #expect(CoreLocationProvider.isUsable(location(accuracy: 65, secondsOld: 120), now: now))
  }

  @Test @MainActor func aVagueLocationIsNotUsable() {
    #expect(!CoreLocationProvider.isUsable(location(accuracy: 501, secondsOld: 5), now: now))
    #expect(CoreLocationProvider.isUsable(location(accuracy: 500, secondsOld: 5), now: now))
  }

  @Test @MainActor func theSamePrecisionRuleAppliesToALiveFix() {
    // `isPrecise` is what the live path uses; age doesn't matter for a fix that just arrived.
    #expect(CoreLocationProvider.isPrecise(location(accuracy: 65, secondsOld: 9_999)))
    #expect(!CoreLocationProvider.isPrecise(location(accuracy: 1_500, secondsOld: 0)))
  }

  @Test @MainActor func aNegativeAccuracyMeansTheLocationIsInvalid() {
    #expect(!CoreLocationProvider.isUsable(location(accuracy: -1, secondsOld: 5), now: now))
  }
}

struct WithTimeoutTests {
  @Test func aFastOperationReturnsItsValue() async {
    let value = await withTimeout(.seconds(5)) { 42 }
    #expect(value == 42)
  }

  @Test func aSlowOperationIsGivenUpOn() async {
    let clock = ContinuousClock()
    let start = clock.now
    let value: Int? = await withTimeout(.milliseconds(50)) {
      try? await Task.sleep(for: .seconds(30))
      return 42
    }
    #expect(value == nil)
    #expect(clock.now - start < .seconds(5))
  }

  @Test func anOperationWithNothingToReturnIsNil() async {
    let value: Int? = await withTimeout(.seconds(5)) { nil }
    #expect(value == nil)
  }
}
