import Testing

@testable import Domain

struct ViaPointsTests {
  /// A straight west-to-east line with vertices at lng 0...4.
  private let line = (0...4).map { LatLng(lat: 0, lng: Double($0)) }

  @Test func nearestIndexPicksTheClosestVertex() {
    #expect(PolylineGeometry.nearestIndex(of: LatLng(lat: 0.1, lng: 2.2), in: line) == 2)
    #expect(PolylineGeometry.nearestIndex(of: LatLng(lat: 0, lng: -5), in: line) == 0)
    #expect(PolylineGeometry.nearestIndex(of: LatLng(lat: 0, lng: 1), in: []) == nil)
  }

  @Test func firstViaGoesFirst() {
    let at = PolylineGeometry.viaInsertionIndex(
      for: LatLng(lat: 0, lng: 2), polyline: line, existingVia: [])
    #expect(at == 0)
  }

  @Test func insertionFollowsOrderAlongTheRoute() {
    let existing = [LatLng(lat: 0, lng: 1), LatLng(lat: 0, lng: 3)]
    #expect(
      PolylineGeometry.viaInsertionIndex(
        for: LatLng(lat: 0, lng: 0), polyline: line, existingVia: existing) == 0)
    #expect(
      PolylineGeometry.viaInsertionIndex(
        for: LatLng(lat: 0, lng: 2), polyline: line, existingVia: existing) == 1)
    #expect(
      PolylineGeometry.viaInsertionIndex(
        for: LatLng(lat: 0, lng: 4), polyline: line, existingVia: existing) == 2)
  }

  @Test func emptyPolylineAppends() {
    let existing = [LatLng(lat: 0, lng: 1)]
    #expect(
      PolylineGeometry.viaInsertionIndex(
        for: LatLng(lat: 0, lng: 0), polyline: [], existingVia: existing) == 1)
  }

  @Test func addMoveRemoveVia() {
    var route = RouteDef(name: "R", color: "#000000")
    #expect(route.addVia(at: LatLng(lat: 0, lng: 3), along: line) == 0)
    #expect(route.addVia(at: LatLng(lat: 0, lng: 1), along: line) == 0)
    #expect(route.via.map(\.lng) == [1, 3])

    route.moveVia(at: 1, to: LatLng(lat: 0, lng: 3.5))
    #expect(route.via[1].lng == 3.5)

    route.removeVia(at: 0)
    #expect(route.via.map(\.lng) == [3.5])
  }

  @Test func outOfRangeMoveAndRemoveAreNoOps() {
    var route = RouteDef(name: "R", color: "#000000", via: [LatLng(lat: 0, lng: 1)])
    route.moveVia(at: 5, to: LatLng(lat: 9, lng: 9))
    route.removeVia(at: -1)
    #expect(route.via == [LatLng(lat: 0, lng: 1)])
  }

  @Test func cannotExceedTheMaximum() {
    var route = RouteDef(
      name: "R", color: "#000000",
      via: Array(repeating: LatLng(lat: 0, lng: 1), count: maxViaPoints))
    #expect(route.canAddVia == false)
    #expect(route.addVia(at: LatLng(lat: 0, lng: 2), along: line) == nil)
    #expect(route.via.count == maxViaPoints)
  }
}
