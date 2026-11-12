import Domain
import Testing

@testable import Mocks

struct InMemoryRouteLineCacheTests {
  private let key = RouteLineKey(
    origin: LatLng(lat: 19.4, lng: -99.1), destination: LatLng(lat: 19.5, lng: -99.2), via: [])

  @Test func unknownRoutesAreMisses() async {
    #expect(await InMemoryRouteLineCache().line(for: key) == nil)
  }

  @Test func storedRoutesComeBack() async {
    let cache = InMemoryRouteLineCache()
    let preview = RoutePreview(distanceMeters: 12_000, polyline: [key.origin, key.destination])
    await cache.store(preview, for: key)
    #expect(await cache.line(for: key) == preview)
  }
}
