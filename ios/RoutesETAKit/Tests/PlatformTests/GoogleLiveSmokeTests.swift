import Domain
import Foundation
import Testing

@testable import Platform

/// Opt-in: hits the real Google Routes API with two requests (one preview, one
/// ETA). Skipped unless `GOOGLE_ROUTES_API_KEY` is in the environment:
///
///     GOOGLE_ROUTES_API_KEY=... swift test --filter GoogleLiveSmokeTests
struct GoogleLiveSmokeTests {
  private static let key = ProcessInfo.processInfo.environment["GOOGLE_ROUTES_API_KEY"]
  private let origin = LatLng(lat: 19.4284, lng: -99.1677)
  private let destination = LatLng(lat: 19.5095, lng: -99.2383)

  private func client() -> GoogleRoutesClient {
    let key = Self.key ?? ""
    return GoogleRoutesClient(apiKey: { key }, bundleIdentifier: nil)
  }

  @Test(.enabled(if: key != nil))
  func previewFollowsRoads() async throws {
    let preview = try await client().previewRoute(
      origin: origin, destination: destination, via: [LatLng(lat: 19.455, lng: -99.205)])
    // A real route has many vertices (a straight mock line has 3) and a plausible length.
    #expect(preview.polyline.count > 20)
    #expect(preview.distanceMeters > 5_000 && preview.distanceMeters < 60_000)
    let start = try #require(preview.polyline.first)
    #expect(abs(start.lat - origin.lat) < 0.01 && abs(start.lng - origin.lng) < 0.01)
  }

  @Test(.enabled(if: key != nil))
  func trafficAwareDurationIsPlausible() async throws {
    let seconds = try await client().routeDurationSeconds(
      origin: origin, destination: destination, via: [])
    #expect(seconds > 5 * 60 && seconds < 3 * 60 * 60)
  }
}
