import Domain
import Foundation
import Testing

@testable import Platform

struct FileRouteLineCacheTests {
  private func makeURL() -> URL {
    FileManager.default.temporaryDirectory
      .appending(path: "routes-eta-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
      .appending(path: "route-lines.json", directoryHint: .notDirectory)
  }

  /// Keys are told apart by their origin's latitude; coordinates have 5 decimals like Google's.
  private func key(_ number: Int) -> RouteLineKey {
    RouteLineKey(
      origin: LatLng(lat: 19.0 + Double(number) / 100, lng: -99.1),
      destination: LatLng(lat: 19.5, lng: -99.2),
      via: [LatLng(lat: 19.45, lng: -99.15)])
  }

  private func preview(_ number: Int) -> RoutePreview {
    RoutePreview(
      distanceMeters: 1000 * number,
      polyline: [
        LatLng(lat: 19.0 + Double(number) / 100, lng: -99.1), LatLng(lat: 19.45, lng: -99.15),
        LatLng(lat: 19.5, lng: -99.2),
      ])
  }

  @Test func missingFileIsAnEmptyCache() async {
    #expect(await FileRouteLineCache(url: makeURL()).line(for: key(1)) == nil)
  }

  @Test func routesSurviveARelaunch() async {
    let url = makeURL()
    await FileRouteLineCache(url: url).store(preview(1), for: key(1))

    // A new instance has nothing in memory, so this reads the file.
    #expect(await FileRouteLineCache(url: url).line(for: key(1)) == preview(1))
  }

  @Test func storingTheSameRouteAgainReplacesIt() async {
    let cache = FileRouteLineCache(url: makeURL())
    await cache.store(preview(1), for: key(1))
    await cache.store(preview(2), for: key(1))
    #expect(await cache.line(for: key(1)) == preview(2))
  }

  @Test func corruptFileIsAnEmptyCacheAndIsReplacedByTheNextStore() async throws {
    let url = makeURL()
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("{ not json".utf8).write(to: url)

    let cache = FileRouteLineCache(url: url)
    #expect(await cache.line(for: key(1)) == nil)
    await cache.store(preview(1), for: key(1))
    #expect(await FileRouteLineCache(url: url).line(for: key(1)) == preview(1))
  }

  @Test func aLineThatCannotBeDecodedIsAMiss() async throws {
    let url = makeURL()
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let json = """
      {"entries":[{"distanceMeters":5,"polyline":" \\u0001",
      "key":{"origin":{"lat":19.01,"lng":-99.1},"destination":{"lat":19.5,"lng":-99.2},"via":[]}}]}
      """
    try Data(json.utf8).write(to: url)
    let bad = RouteLineKey(
      origin: LatLng(lat: 19.01, lng: -99.1), destination: LatLng(lat: 19.5, lng: -99.2), via: [])

    #expect(await FileRouteLineCache(url: url).line(for: bad) == nil)
  }

  @Test func theLeastRecentlyUsedRouteIsDroppedWhenFull() async {
    let cache = FileRouteLineCache(url: makeURL(), capacity: 2)
    await cache.store(preview(1), for: key(1))
    await cache.store(preview(2), for: key(2))
    await cache.store(preview(3), for: key(3))

    #expect(await cache.line(for: key(1)) == nil)
    #expect(await cache.line(for: key(2)) == preview(2))
    #expect(await cache.line(for: key(3)) == preview(3))
  }

  @Test func readingARouteKeepsItFromBeingDropped() async {
    let cache = FileRouteLineCache(url: makeURL(), capacity: 2)
    await cache.store(preview(1), for: key(1))
    await cache.store(preview(2), for: key(2))
    _ = await cache.line(for: key(1))  // 1 is now newer than 2
    await cache.store(preview(3), for: key(3))

    #expect(await cache.line(for: key(1)) == preview(1))
    #expect(await cache.line(for: key(2)) == nil)
  }

  @Test func theCapacityIsKeptAcrossARelaunch() async {
    let url = makeURL()
    let first = FileRouteLineCache(url: url, capacity: 2)
    for number in 1...3 { await first.store(preview(number), for: key(number)) }

    let relaunched = FileRouteLineCache(url: url, capacity: 2)
    #expect(await relaunched.line(for: key(1)) == nil)
    #expect(await relaunched.line(for: key(3)) == preview(3))
  }
}
