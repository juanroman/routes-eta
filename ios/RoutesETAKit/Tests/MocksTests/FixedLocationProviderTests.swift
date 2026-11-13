import Domain
import Testing

@testable import Mocks

struct FixedLocationProviderTests {
  private let home = LatLng(lat: 19.43, lng: -99.13)

  @Test func anAuthorizedUserIsWhereYouPutThem() async {
    let provider = FixedLocationProvider(authorization: .authorized, location: home)
    #expect(await provider.authorization() == .authorized)
    #expect(await provider.currentLocation(timeout: .seconds(1)) == home)
  }

  @Test func withoutPermissionThereIsNoLocation() async {
    let denied = FixedLocationProvider(authorization: .denied, location: home)
    #expect(await denied.currentLocation(timeout: .seconds(1)) == nil)
    let undecided = FixedLocationProvider(authorization: .notDetermined, location: home)
    #expect(await undecided.currentLocation(timeout: .seconds(1)) == nil)
  }

  @Test func askingResolvesAnUndecidedUser() async {
    let granting = FixedLocationProvider(authorization: .notDetermined, location: home)
    #expect(await granting.requestAuthorization() == .authorized)
    #expect(await granting.currentLocation(timeout: .seconds(1)) == home)

    let refusing = FixedLocationProvider(
      authorization: .notDetermined, location: home, grantsOnRequest: false)
    #expect(await refusing.requestAuthorization() == .denied)
    #expect(await refusing.currentLocation(timeout: .seconds(1)) == nil)
  }

  @Test func theUserIsOnlyAskedOnce() async {
    let provider = FixedLocationProvider(authorization: .notDetermined, grantsOnRequest: false)
    _ = await provider.requestAuthorization()
    _ = await provider.requestAuthorization()
    #expect(await provider.requestCount == 1)
  }

  @Test func aDecidedUserIsNeverAsked() async {
    let provider = FixedLocationProvider(authorization: .denied)
    #expect(await provider.requestAuthorization() == .denied)
    #expect(await provider.requestCount == 0)
  }

  @Test func unavailableNeverKnowsAndNeverAsks() async {
    let provider = UnavailableLocationProvider()
    #expect(await provider.authorization() == .denied)
    #expect(await provider.requestAuthorization() == .denied)
    #expect(await provider.currentLocation(timeout: .seconds(1)) == nil)
  }
}
