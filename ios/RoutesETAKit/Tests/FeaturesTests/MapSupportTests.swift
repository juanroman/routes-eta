import CoreGraphics
import Domain
import Mocks
import Testing

@testable import Features

struct ScreenGeometryTests {
  private let line = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0), CGPoint(x: 100, y: 100)]

  @Test func distanceToASegmentIsPerpendicular() {
    #expect(ScreenGeometry.distance(from: CGPoint(x: 50, y: 10), toPolyline: line) == 10)
  }

  @Test func distanceClampsToTheEndpoints() {
    #expect(ScreenGeometry.distance(from: CGPoint(x: -30, y: 40), toPolyline: line) == 50)
  }

  @Test func distanceUsesTheNearestOfAllSegments() {
    #expect(ScreenGeometry.distance(from: CGPoint(x: 90, y: 50), toPolyline: line) == 10)
  }

  @Test func degenerateInputs() {
    #expect(ScreenGeometry.distance(from: .zero, toPolyline: []) == .infinity)
    #expect(ScreenGeometry.distance(from: CGPoint(x: 3, y: 4), toPolyline: [.zero]) == 5)
  }

  @Test func nearTestsEveryHandle() {
    let handles = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 100)]
    #expect(ScreenGeometry.isNear(CGPoint(x: 95, y: 100), anyOf: handles, within: 30))
    #expect(!ScreenGeometry.isNear(CGPoint(x: 50, y: 50), anyOf: handles, within: 30))
    #expect(!ScreenGeometry.isNear(.zero, anyOf: [], within: 30))
  }
}

struct MapRegionFitTests {
  @Test func centersOnTheBoundingBoxWithPadding() {
    let region = MapRegionFit.region(fitting: [
      LatLng(lat: 19.0, lng: -99.0), LatLng(lat: 19.2, lng: -99.4),
    ])
    #expect(abs(region.center.latitude - 19.1) < 1e-9)
    #expect(abs(region.center.longitude - -99.2) < 1e-9)
    #expect(abs(region.span.latitudeDelta - 0.3) < 1e-9)
    #expect(abs(region.span.longitudeDelta - 0.6) < 1e-9)
  }

  @Test func neverTighterThanTheMinimumSpan() {
    let region = MapRegionFit.region(fitting: [LatLng(lat: 19, lng: -99)])
    #expect(region.span.latitudeDelta == 0.01)
  }

  @Test func emptyFallsBackToMexicoCity() {
    #expect(
      MapRegionFit.region(fitting: []).center.latitude == MapRegionFit.fallback.center.latitude)
  }
}

@MainActor
struct RouteMapModelTests {
  private let origin = SampleData.work.latLng
  private let destination = SampleData.home.latLng

  @Test func loadsAPolylineThroughTheViaPoints() async {
    let model = RouteMapModel(service: MockRoutePreviewService())
    let via = [LatLng(lat: 19.45, lng: -99.2)]
    await model.load(origin: origin, destination: destination, via: via)
    #expect(model.status == .loaded)
    #expect(model.polyline == [origin] + via + [destination])
    #expect((model.distanceMeters ?? 0) > 0)
  }

  @Test func failureKeepsThePreviousPolyline() async {
    struct Flaky: RoutePreviewService {
      let fail: Bool
      func preview(origin: LatLng, destination: LatLng, via: [LatLng]) async throws
        -> RoutePreview
      {
        if fail { throw PlaceSearchError.notFound }
        return RoutePreview(distanceMeters: 1, polyline: [origin, destination])
      }
    }
    let model = RouteMapModel(service: Flaky(fail: false))
    await model.load(origin: origin, destination: destination, via: [])
    let drawn = model.polyline

    let failing = RouteMapModel(service: Flaky(fail: true))
    await failing.load(origin: origin, destination: destination, via: [])
    #expect(failing.status == .failed)
    #expect(failing.polyline.isEmpty)
    #expect(drawn.count == 2)
  }

  @Test func aCancelledLoadNeverPublishesItsResult() async {
    struct Slow: RoutePreviewService {
      func preview(origin: LatLng, destination: LatLng, via: [LatLng]) async throws
        -> RoutePreview
      {
        try await Task.sleep(for: .seconds(5))
        return RoutePreview(distanceMeters: 1, polyline: [origin, destination])
      }
    }
    let model = RouteMapModel(service: Slow())
    let task = Task { await model.load(origin: origin, destination: destination, via: []) }
    try? await Task.sleep(for: .milliseconds(50))
    task.cancel()
    await task.value
    #expect(model.polyline.isEmpty)
    #expect(model.status != .loaded)
  }
}
