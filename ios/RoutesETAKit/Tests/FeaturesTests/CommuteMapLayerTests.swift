import CoreGraphics
import Domain
import Testing

@testable import Features

@MainActor
struct CommuteMapLayerTests {
  private let work = NamedPoint(label: "Work", lat: 19.40, lng: -99.20)
  private let home = NamedPoint(label: "Home", lat: 19.50, lng: -99.10)

  private var commute: Commute {
    Commute(
      name: "Work to Home", origin: work, destination: home,
      routes: [
        RouteDef(name: "City", color: "#2563eb"), RouteDef(name: "Mordor", color: "#dc2626"),
      ])
  }

  private let cityLine = [LatLng(lat: 19.40, lng: -99.20), LatLng(lat: 19.45, lng: -99.18)]
  private let mordorLine = [LatLng(lat: 19.40, lng: -99.20), LatLng(lat: 19.50, lng: -99.10)]

  private func layer(selected: String? = nil, lines: [Int: [LatLng]]? = nil) -> CommuteMapLayer {
    CommuteMapLayer(
      commute: commute, lines: lines ?? [0: cityLine, 1: mordorLine], selected: selected)
  }

  @Test func withNothingSelectedEveryLineIsFramed() {
    let framing = layer().framing
    #expect(framing.contains(cityLine[1]))
    #expect(framing.contains(mordorLine[1]))
  }

  @Test func aSelectedRouteFramesOnlyItsOwnLineAndTheEndpoints() {
    let framing = layer(selected: "City").framing
    #expect(framing.contains(cityLine[1]))
    #expect(!framing.contains(mordorLine[0]) || cityLine.contains(mordorLine[0]))
    #expect(framing == [work.latLng, home.latLng] + cityLine)
  }

  @Test func theEndpointsAreFramedBeforeAnyLineHasLoaded() {
    #expect(layer(lines: [:]).framing == [work.latLng, home.latLng])
  }

  @Test func theSelectionIsFoundByNameAndAnUnknownNameSelectsNothing() {
    #expect(layer(selected: "Mordor").selectedIndex == 1)
    #expect(layer(selected: "Gone").selectedIndex == nil)
    #expect(layer().selectedIndex == nil)
  }

  @Test func theSummaryNamesTheRoutesAndTheEnds() {
    #expect(layer().summary == "Map of 2 routes from Work to Home")
    let bare = CommuteMapLayer(commute: Commute(name: "Gym"), lines: [:], selected: nil)
    #expect(bare.summary == "Map of Gym")
  }

  /// Lines are given directly in screen points here: City runs along y = 0 and Mordor along
  /// y = 40, closer together than twice the hit radius so one tap can be in reach of both.
  private func screen(_ line: [LatLng]) -> [CGPoint] {
    line == cityLine
      ? [CGPoint(x: 0, y: 0), CGPoint(x: 200, y: 0)]
      : [CGPoint(x: 0, y: 40), CGPoint(x: 200, y: 40)]
  }

  @Test func aTapNearALineSelectsThatRoute() {
    #expect(layer().route(near: CGPoint(x: 50, y: -10), screenLine: screen) == "City")
    #expect(layer().route(near: CGPoint(x: 50, y: 45), screenLine: screen) == "Mordor")
  }

  @Test func whenTwoLinesAreInReachTheNearerWins() {
    #expect(layer().route(near: CGPoint(x: 50, y: 25), screenLine: screen) == "Mordor")
    #expect(layer().route(near: CGPoint(x: 50, y: 14), screenLine: screen) == "City")
  }

  @Test func aTapOnEmptyMapSelectsNothing() {
    #expect(layer().route(near: CGPoint(x: 50, y: 200), screenLine: screen) == nil)
    #expect(layer().route(near: CGPoint(x: 500, y: 0), screenLine: screen) == nil)
  }

  @Test func routesWithoutALineCannotBeTapped() {
    let loadedOnlyMordor = layer(lines: [1: mordorLine])
    #expect(loadedOnlyMordor.route(near: CGPoint(x: 50, y: -20), screenLine: screen) == nil)
  }
}
