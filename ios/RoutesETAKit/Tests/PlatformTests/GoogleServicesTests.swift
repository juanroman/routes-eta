import Domain
import Foundation
import Mocks
import Testing

@testable import Platform

struct GoogleServicesTests {
  private let work = NamedPoint(label: "Work", lat: 19.4284, lng: -99.1677)
  private let home = NamedPoint(label: "Home", lat: 19.5095, lng: -99.2383)

  private func repository(
    routes: [RouteDef], origin: NamedPoint? = nil, destination: NamedPoint? = nil
  )
    -> InMemoryConfigRepository
  {
    InMemoryConfigRepository(
      initial: Config(commutes: [
        Commute(
          name: "C", origin: origin ?? work, destination: destination ?? home, routes: routes)
      ]))
  }

  /// Answers by how many via points the request carries, so routes can be made to
  /// succeed or fail independently: 0 via -> 1800s, 1 via -> 500, 2 via -> 1710s.
  private func serviceClient() -> GoogleRoutesClient {
    GoogleRoutesClient(
      session: Stub.session { request in
        let body = try Stub.json(request)
        let count = (body["intermediates"] as? [Any])?.count ?? 0
        switch count {
        case 1: return Stub.respond(500, #"{"error":{"message":"boom"}}"#, for: request)
        case 2: return Stub.respond(200, #"{"routes":[{"duration":"1710s"}]}"#, for: request)
        default: return Stub.respond(200, #"{"routes":[{"duration":"1800s"}]}"#, for: request)
        }
      },
      apiKey: { "test-key" }, bundleIdentifier: nil)
  }

  private func via(_ count: Int) -> [LatLng] {
    Array(repeating: LatLng(lat: 19.45, lng: -99.2), count: count)
  }

  @Test func routesAreReportedInOrderWithMinutesRoundedLikePython() async throws {
    let routes = [
      RouteDef(name: "Direct", color: "#000000"),
      RouteDef(name: "Scenic", color: "#111111", via: via(2)),
    ]
    let service = GoogleETAService(client: serviceClient(), repository: repository(routes: routes))
    let report = try await service.run(commute: "C")
    #expect(report.results.map(\.name) == ["Direct", "Scenic"])
    #expect(report.results.map(\.minutes) == [30, 28])  // 1800s; 1710s = 28.5 -> 28
    #expect(report.message == "C: Direct 30 · Scenic 28")
  }

  @Test func oneRoutesMinutesAreRoundedLikeTheReport() async throws {
    let service = GoogleETAService(client: serviceClient(), repository: repository(routes: []))
    let scenic = RouteDef(name: "Scenic", color: "#111111", via: via(2))
    let minutes = try await service.minutes(for: scenic, from: work.latLng, to: home.latLng)
    #expect(minutes == 28)  // 1710s = 28.5 -> 28, the same as in the full report
  }

  @Test func oneRoutesFailureIsThrownForTheCallerToShow() async {
    let service = GoogleETAService(client: serviceClient(), repository: repository(routes: []))
    let broken = RouteDef(name: "Broken", color: "#111111", via: via(1))
    await #expect(throws: GoogleRoutesError.self) {
      try await service.minutes(for: broken, from: work.latLng, to: home.latLng)
    }
  }

  @Test func oneFailingRouteDoesNotSinkTheOthers() async throws {
    let routes = [
      RouteDef(name: "Direct", color: "#000000"),
      RouteDef(name: "Broken", color: "#111111", via: via(1)),
      RouteDef(name: "Scenic", color: "#222222", via: via(2)),
    ]
    let service = GoogleETAService(client: serviceClient(), repository: repository(routes: routes))
    let report = try await service.run(commute: "C")
    #expect(report.results.map(\.minutes) == [30, nil, 28])
    #expect(report.results[1].error?.contains("boom") == true)
    #expect(report.allFailed == false)
    #expect(report.message == "C: Direct 30 · Broken ? · Scenic 28")
  }

  @Test func everyRouteFailingIsAnAllFailedReport() async throws {
    let routes = [RouteDef(name: "Broken", color: "#111111", via: via(1))]
    let service = GoogleETAService(client: serviceClient(), repository: repository(routes: routes))
    let report = try await service.run(commute: "C")
    #expect(report.allFailed)
    #expect(report.message == "C: Couldn't fetch ETAs")
  }

  @Test func aMissingKeyIsReportedOnceUpFrontNotPerRoute() async throws {
    let calls = LockedBox(0)
    let client = GoogleRoutesClient(
      session: Stub.session { request in
        calls.value += 1
        return Stub.respond(200, "{}", for: request)
      },
      apiKey: { throw GoogleAPIKey.Failure.missingFile }, bundleIdentifier: nil)
    let routes = [RouteDef(name: "A", color: "#000000"), RouteDef(name: "B", color: "#111111")]
    let service = GoogleETAService(client: client, repository: repository(routes: routes))
    await #expect(throws: GoogleRoutesError.missingKey(.missingFile)) {
      try await service.run(commute: "C")
    }
    #expect(calls.value == 0)
  }

  @Test func unknownAndIncompleteCommutesAreRejectedWithoutRequests() async throws {
    let service = GoogleETAService(
      client: serviceClient(),
      repository: InMemoryConfigRepository(
        initial: Config(commutes: [Commute(name: "Empty", routes: [])])))
    await #expect(throws: ETAServiceError.unknownCommute("Nope")) {
      try await service.run(commute: "Nope")
    }
    await #expect(throws: ETAServiceError.notReady("Set origin and destination first")) {
      try await service.run(commute: "Empty")
    }
  }

  @Test func previewServiceForwardsViaPointsAsThroughWaypoints() async throws {
    let seen = LockedBox(0)
    let client = GoogleRoutesClient(
      session: Stub.session { request in
        let body = try Stub.json(request)
        seen.value = (body["intermediates"] as? [Any])?.count ?? -1
        return Stub.respond(
          200,
          #"{"routes":[{"distanceMeters":10,"polyline":{"encodedPolyline":"_p~iF~ps|U"}}]}"#,
          for: request)
      },
      apiKey: { "k" }, bundleIdentifier: nil)
    let preview = try await GoogleRoutePreviewService(client: client).preview(
      origin: work.latLng, destination: home.latLng, via: via(2))
    #expect(seen.value == 2)
    #expect(preview.polyline == [LatLng(lat: 38.5, lng: -120.2)])
  }
}
