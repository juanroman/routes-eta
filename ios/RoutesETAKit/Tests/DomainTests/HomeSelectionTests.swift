import Testing

@testable import Domain

struct HomeSelectionTests {
  private let home = LatLng(lat: 19.4300, lng: -99.1300)
  /// About 550 m from `home`.
  private let nearHome = LatLng(lat: 19.4350, lng: -99.1300)
  /// About 2.2 km from `home`.
  private let farFromHome = LatLng(lat: 19.4500, lng: -99.1300)
  private let work = LatLng(lat: 19.3600, lng: -99.2000)

  private func commute(_ name: String, from origin: (String, LatLng)?) -> Commute {
    Commute(
      name: name,
      origin: origin.map { NamedPoint(label: $0.0, lat: $0.1.lat, lng: $0.1.lng) })
  }

  private func commutes() -> [Commute] {
    [
      commute("Home to Work", from: ("Home", home)),
      commute("Work to Home", from: ("Work", work)),
      commute("Home to School", from: ("Home", home)),
    ]
  }

  @Test func noCommutesPicksNothing() {
    #expect(HomeSelection.pick(commutes: [], recent: ["A"], here: home) == nil)
  }

  @Test func nearAnOriginPicksThatCommuteAndSaysWhy() {
    let pick = HomeSelection.pick(commutes: commutes(), recent: [], here: work)
    #expect(pick == HomeSelection(name: "Work to Home", reason: .near(originLabel: "Work")))
  }

  @Test func severalNearbyPicksTheMostRecentlyViewed() {
    let recent = ["Work to Home", "Home to School", "Home to Work"]
    let pick = HomeSelection.pick(commutes: commutes(), recent: recent, here: nearHome)
    #expect(pick == HomeSelection(name: "Home to School", reason: .near(originLabel: "Home")))
  }

  @Test func mostRecentBeatsNearest() {
    // Two origins near the user; the farther one was viewed last, so it wins.
    let list = [
      commute("Gym", from: ("Gym", nearHome)),
      commute("Home to Work", from: ("Home", home)),
    ]
    let pick = HomeSelection.pick(commutes: list, recent: ["Home to Work"], here: nearHome)
    #expect(pick?.name == "Home to Work")
  }

  @Test func severalNearbyWithoutHistoryPicksTheFirstInList() {
    let pick = HomeSelection.pick(commutes: commutes(), recent: [], here: home)
    #expect(pick?.name == "Home to Work")
  }

  @Test func neverViewedRankBehindViewedOnes() {
    let pick = HomeSelection.pick(commutes: commutes(), recent: ["Home to School"], here: home)
    #expect(pick?.name == "Home to School")
  }

  @Test func nothingNearFallsBackToLastViewed() {
    let pick = HomeSelection.pick(
      commutes: commutes(), recent: ["Work to Home", "Home to Work"], here: farFromHome)
    #expect(pick == HomeSelection(name: "Work to Home", reason: .lastViewed))
  }

  @Test func noLocationFallsBackToLastViewed() {
    let pick = HomeSelection.pick(commutes: commutes(), recent: ["Home to School"], here: nil)
    #expect(pick == HomeSelection(name: "Home to School", reason: .lastViewed))
  }

  @Test func noHistoryFallsBackToTheFirstInList() {
    let pick = HomeSelection.pick(commutes: commutes(), recent: [], here: nil)
    #expect(pick == HomeSelection(name: "Home to Work", reason: .firstInList))
  }

  @Test func historyOfDeletedCommutesIsIgnored() {
    let pick = HomeSelection.pick(
      commutes: commutes(), recent: ["Deleted", "Renamed", "Work to Home"], here: nil)
    #expect(pick == HomeSelection(name: "Work to Home", reason: .lastViewed))

    let onlyStale = HomeSelection.pick(commutes: commutes(), recent: ["Deleted"], here: nil)
    #expect(onlyStale?.reason == .firstInList)
  }

  @Test func commutesWithoutAnOriginAreNeverNear() {
    let list = [commute("No origin", from: nil), commute("Home to Work", from: ("Home", home))]
    let pick = HomeSelection.pick(commutes: list, recent: ["No origin"], here: home)
    #expect(pick?.name == "Home to Work")
  }

  @Test func theRadiusIsInclusiveAndConfigurable() {
    let list = [commute("Home to Work", from: ("Home", home))]
    let distance = home.distance(to: nearHome)

    let inside = HomeSelection.pick(
      commutes: list, recent: [], here: nearHome, radiusMeters: distance)
    #expect(inside?.reason == .near(originLabel: "Home"))

    let outside = HomeSelection.pick(
      commutes: list, recent: [], here: nearHome, radiusMeters: distance - 1)
    #expect(outside?.reason == .firstInList)
  }

  @Test func theDefaultRadiusIsAboutAKilometer() {
    #expect(HomeSelection.defaultRadiusMeters == 1_000)
    let list = [commute("Home to Work", from: ("Home", home))]
    #expect(
      HomeSelection.pick(commutes: list, recent: [], here: nearHome)?.reason
        == .near(originLabel: "Home"))
    #expect(
      HomeSelection.pick(commutes: list, recent: [], here: farFromHome)?.reason == .firstInList)
  }
}

struct LatLngDistanceTests {
  @Test func aDegreeOfLatitudeIsAbout111Kilometers() {
    let meters = LatLng(lat: 0, lng: 0).distance(to: LatLng(lat: 1, lng: 0))
    #expect(abs(meters - 111_195) < 50)
  }

  @Test func distanceIsSymmetricAndZeroToItself() {
    let first = LatLng(lat: 19.43, lng: -99.13)
    let second = LatLng(lat: 19.36, lng: -99.20)
    #expect(first.distance(to: first) == 0)
    #expect(abs(first.distance(to: second) - second.distance(to: first)) < 0.001)
  }

  @Test func longitudeShrinksWithLatitude() {
    let atEquator = LatLng(lat: 0, lng: 0).distance(to: LatLng(lat: 0, lng: 1))
    let atMexicoCity = LatLng(lat: 19.43, lng: 0).distance(to: LatLng(lat: 19.43, lng: 1))
    #expect(atMexicoCity < atEquator)
    #expect(abs(atMexicoCity - 104_900) < 500)
  }
}
