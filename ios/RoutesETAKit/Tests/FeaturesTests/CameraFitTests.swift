import CoreGraphics
import Domain
import MapKit
import Testing

@testable import Features

struct CameraFitTests {
  /// A portrait phone: tall and narrow, which makes most routes width-limited.
  private let mapSize = CGSize(width: 402, height: 874)

  private func screenPoint(_ point: MKMapPoint, in rect: MKMapRect) -> CGPoint {
    CGPoint(
      x: (point.x - rect.minX) / rect.width * mapSize.width,
      y: (point.y - rect.minY) / rect.height * mapSize.height)
  }

  private func screenPoint(_ point: LatLng, in rect: MKMapRect) -> CGPoint {
    screenPoint(MKMapPoint(point.coordinate), in: rect)
  }

  private let wide = [LatLng(lat: 19.43, lng: -99.25), LatLng(lat: 19.45, lng: -99.05)]
  private let tall = [LatLng(lat: 19.30, lng: -99.15), LatLng(lat: 19.55, lng: -99.14)]
  private let diagonal = [
    LatLng(lat: 19.36, lng: -99.20), LatLng(lat: 19.43, lng: -99.17),
    LatLng(lat: 19.48, lng: -99.08),
  ]

  @Test(arguments: [0, 1, 2])
  func everyPointLandsInsideTheUncoveredPart(shape: Int) throws {
    let points = [wide, tall, diagonal][shape]
    let top: CGFloat = 110
    let bottom: CGFloat = 437  // a medium sheet
    let rect = try #require(
      CameraFit.rect(
        fitting: points, mapSize: mapSize, topInset: top, bottomInset: bottom, padding: 48))

    for point in points {
      let screen = screenPoint(point, in: rect)
      #expect(screen.x >= 47.5 && screen.x <= mapSize.width - 47.5)
      #expect(screen.y >= top + 47.5 && screen.y <= mapSize.height - bottom - 47.5)
    }
  }

  /// The case that hid markers under the sheet: a width-limited route, where the vertical
  /// scale is set by the width and not by the height.
  @Test func aWidthLimitedRouteIsCentredInTheUncoveredPart() throws {
    let top: CGFloat = 110
    let bottom: CGFloat = 437
    let rect = try #require(
      CameraFit.rect(fitting: wide, mapSize: mapSize, topInset: top, bottomInset: bottom))

    let mapPoints = wide.map { MKMapPoint($0.coordinate) }
    let middle = MKMapPoint(
      x: (mapPoints[0].x + mapPoints[1].x) / 2, y: (mapPoints[0].y + mapPoints[1].y) / 2)

    let screen = screenPoint(middle, in: rect)
    #expect(abs(screen.x - mapSize.width / 2) < 0.5)
    #expect(abs(screen.y - (top + (mapSize.height - top - bottom) / 2)) < 0.5)
  }

  @Test func aTallerSheetPushesTheContentUp() throws {
    let small = try #require(
      CameraFit.rect(fitting: diagonal, mapSize: mapSize, topInset: 110, bottomInset: 230))
    let medium = try #require(
      CameraFit.rect(fitting: diagonal, mapSize: mapSize, topInset: 110, bottomInset: 437))

    let first = diagonal[0]
    #expect(screenPoint(first, in: medium).y < screenPoint(first, in: small).y)
  }

  @Test func theTopBarPushesTheContentDown() throws {
    let bare = try #require(
      CameraFit.rect(fitting: diagonal, mapSize: mapSize, topInset: 0, bottomInset: 230))
    let withBar = try #require(
      CameraFit.rect(fitting: diagonal, mapSize: mapSize, topInset: 110, bottomInset: 230))

    let first = diagonal[0]
    #expect(screenPoint(first, in: withBar).y > screenPoint(first, in: bare).y)
  }

  @Test func aSinglePointDoesNotZoomInToTheStreet() throws {
    let point = LatLng(lat: 19.4326, lng: -99.1332)
    let rect = try #require(
      CameraFit.rect(fitting: [point], mapSize: mapSize, topInset: 110, bottomInset: 230))

    // The map is at least a kilometre across in its tighter direction.
    let visibleMeters = rect.width / MKMapPointsPerMeterAtLatitude(point.lat)
    #expect(visibleMeters >= CameraFit.minimumExtentMeters)
  }

  @Test func nothingToFrameOrNoSizeYetGivesNoRect() {
    #expect(
      CameraFit.rect(fitting: [], mapSize: mapSize, topInset: 0, bottomInset: 0) == nil)
    #expect(
      CameraFit.rect(fitting: wide, mapSize: .zero, topInset: 0, bottomInset: 0) == nil)
  }

  @Test func theRectKeepsTheMapsShape() throws {
    let rect = try #require(
      CameraFit.rect(fitting: tall, mapSize: mapSize, topInset: 110, bottomInset: 230))
    #expect(abs(rect.width / rect.height - mapSize.width / mapSize.height) < 0.0001)
  }

  @Test func aSheetTallerThanTheMapStillLeavesRoomForTheContent() throws {
    let rect = try #require(
      CameraFit.rect(fitting: wide, mapSize: mapSize, topInset: 110, bottomInset: 2000))
    #expect(rect.width.isFinite && rect.width > 0)
  }
}
