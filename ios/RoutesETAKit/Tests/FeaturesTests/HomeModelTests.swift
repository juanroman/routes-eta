import Domain
import Foundation
import Mocks
import Testing

@testable import Features

/// Counts which commutes were fetched, delegating to the deterministic mock.
actor RecordingETAService: ETAService {
  private let wrapped: MockETAService
  private(set) var ran: [String] = []

  init(repository: any ConfigRepository) {
    wrapped = MockETAService(repository: repository)
  }

  func run(commute name: String) async throws -> ETAReport {
    ran.append(name)
    return try await wrapped.run(commute: name)
  }

  func minutes(
    for route: RouteDef, from origin: LatLng, to destination: LatLng
  ) async throws -> Int {
    try await wrapped.minutes(for: route, from: origin, to: destination)
  }
}

@MainActor
struct HomeModelTests {
  private static let home = NamedPoint(label: "Home", lat: 19.4300, lng: -99.1300)
  private static let work = NamedPoint(label: "Work", lat: 19.3600, lng: -99.2000)
  private static let gym = NamedPoint(label: "Gym", lat: 19.4800, lng: -99.0500)

  private static func commute(_ name: String, from origin: NamedPoint?) -> Commute {
    Commute(
      name: name, origin: origin, destination: work,
      routes: [
        RouteDef(name: "City", color: "#2563eb"), RouteDef(name: "Ring", color: "#dc2626"),
        RouteDef(name: "Back streets", color: "#16a34a"),
      ])
  }

  /// "Home to Work" and "Home to Gym" start at home; "Work to Home" starts at work.
  private static let commutes = [
    commute("Home to Work", from: home),
    commute("Work to Home", from: work),
    commute("Home to Gym", from: home),
  ]

  private struct Fixture {
    let model: HomeModel
    let store: ConfigStore
    let service: RecordingETAService
    let recents: InMemoryRecentCommutesRepository
    let location: FixedLocationProvider
    let prompts: InMemoryLocationPromptRepository
  }

  private func makeFixture(
    commutes: [Commute] = HomeModelTests.commutes,
    authorization: LocationAuthorization = .authorized, at point: NamedPoint? = nil,
    recent: [String] = [], declined: Bool = false, freshFor: TimeInterval = 5
  ) async -> Fixture {
    let repository = InMemoryConfigRepository(initial: Config(commutes: commutes))
    let store = ConfigStore(repository: repository)
    await store.load()
    let service = RecordingETAService(repository: repository)
    let recents = InMemoryRecentCommutesRepository(initial: recent)
    let location = FixedLocationProvider(authorization: authorization, location: point?.latLng)
    let prompts = InMemoryLocationPromptRepository(declined: declined)
    let model = HomeModel(
      store: store, service: service, location: location, recents: recents, prompts: prompts,
      freshFor: freshFor)
    return Fixture(
      model: model, store: store, service: service, recents: recents, location: location,
      prompts: prompts)
  }

  private func report(of model: HomeModel) -> ETAReport? {
    guard case .loaded(let report, _) = model.eta?.state else { return nil }
    return report
  }

  // MARK: - Choosing the commute

  @Test func nearAnOriginShowsThatCommuteAndSaysWhy() async {
    let fixture = await makeFixture(at: Self.work)
    await fixture.model.open()
    #expect(fixture.model.phase == .ready)
    #expect(fixture.model.selectedName == "Work to Home")
    #expect(fixture.model.reason == .near(originLabel: "Work"))
    #expect(report(of: fixture.model)?.commute == "Work to Home")
  }

  @Test func onlyTheChosenCommuteIsFetched() async {
    let fixture = await makeFixture(at: Self.work)
    await fixture.model.open()
    #expect(await fixture.service.ran == ["Work to Home"])
  }

  @Test func severalNearbyShowsTheMostRecentlyViewed() async {
    let fixture = await makeFixture(at: Self.home, recent: ["Home to Gym", "Home to Work"])
    await fixture.model.open()
    #expect(fixture.model.selectedName == "Home to Gym")
  }

  @Test func withoutPermissionItShowsTheLastViewed() async {
    let fixture = await makeFixture(
      authorization: .denied, at: Self.work, recent: ["Home to Gym"])
    await fixture.model.open()
    #expect(fixture.model.selectedName == "Home to Gym")
    #expect(fixture.model.reason == .lastViewed)
  }

  @Test func nothingNearShowsTheLastViewed() async {
    let fixture = await makeFixture(at: Self.gym, recent: ["Work to Home"])
    await fixture.model.open()
    #expect(fixture.model.selectedName == "Work to Home")
    #expect(fixture.model.reason == .lastViewed)
  }

  @Test func withNoHistoryAndNoLocationItShowsTheFirstInTheList() async {
    let fixture = await makeFixture(authorization: .denied)
    await fixture.model.open()
    #expect(fixture.model.selectedName == "Home to Work")
    #expect(fixture.model.reason == .firstInList)
  }

  @Test func theChosenCommuteCountsAsViewed() async throws {
    let fixture = await makeFixture(at: Self.work)
    await fixture.model.open()
    #expect(try await fixture.recents.load() == ["Work to Home"])
  }

  @Test func noCommutesIsAnEmptyState() async {
    let fixture = await makeFixture(commutes: [])
    await fixture.model.open()
    #expect(fixture.model.phase == .empty)
    #expect(fixture.model.eta == nil)
    #expect(await fixture.service.ran.isEmpty)
  }

  @Test func routesComeInTheCommutesOwnOrder() async {
    let fixture = await makeFixture(at: Self.work)
    await fixture.model.open()
    #expect(report(of: fixture.model)?.results.map(\.name) == ["City", "Ring", "Back streets"])
  }

  // MARK: - Choosing by hand

  @Test func pickingAnotherCommuteReplacesTheNumbersWithItsOwn() async throws {
    let fixture = await makeFixture(at: Self.work)
    await fixture.model.open()
    let first = fixture.model.eta

    await fixture.model.select("Home to Gym")
    #expect(fixture.model.selectedName == "Home to Gym")
    #expect(fixture.model.reason == nil)
    #expect(fixture.model.eta !== first)
    #expect(report(of: fixture.model)?.commute == "Home to Gym")
    #expect(try await fixture.recents.load().first == "Home to Gym")
    #expect(await fixture.service.ran == ["Work to Home", "Home to Gym"])
  }

  @Test func pickingTheCommuteOnScreenDoesNothing() async {
    let fixture = await makeFixture(at: Self.work)
    await fixture.model.open()
    await fixture.model.select("Work to Home")
    #expect(await fixture.service.ran == ["Work to Home"])
  }

  // MARK: - Refreshing

  @Test func refreshFetchesAgainAndKeepsTheCommute() async {
    let fixture = await makeFixture(at: Self.work)
    await fixture.model.open()
    await fixture.model.refresh()
    #expect(fixture.model.eta?.isRefreshing == false)
    #expect(report(of: fixture.model)?.commute == "Work to Home")
    #expect(await fixture.service.ran == ["Work to Home", "Work to Home"])
  }

  @Test func retryFetchesAgain() async {
    let fixture = await makeFixture(at: Self.work)
    await fixture.model.open()
    await fixture.model.retry()
    #expect(await fixture.service.ran.count == 2)
  }

  // MARK: - Coming back

  @Test func comingBackRightAfterAFetchWithNothingChangedDoesNotFetchAgain() async {
    let fixture = await makeFixture(at: Self.work, freshFor: 60)
    await fixture.model.open()
    await fixture.model.reopenIfNeeded()
    #expect(await fixture.service.ran.count == 1)
  }

  @Test func comingBackWhenTheNumbersAreOldFetchesAgain() async {
    let fixture = await makeFixture(at: Self.work, freshFor: 0)
    await fixture.model.open()
    await fixture.model.reopenIfNeeded()
    #expect(await fixture.service.ran.count == 2)
  }

  @Test func comingBackAfterRenamingTheShownCommuteChoosesAgain() async throws {
    let fixture = await makeFixture(at: Self.work, freshFor: 60)
    await fixture.model.open()
    let id = try #require(fixture.store.entries.first { $0.commute.name == "Work to Home" }?.id)
    await fixture.store.renameCommute(id: id, to: "Back home")

    await fixture.model.reopenIfNeeded()
    #expect(fixture.model.selectedName == "Back home")
    #expect(report(of: fixture.model)?.commute == "Back home")
  }

  @Test func comingBackAfterDeletingTheShownCommuteChoosesAnother() async throws {
    let fixture = await makeFixture(authorization: .denied, freshFor: 60)
    await fixture.model.open()
    #expect(fixture.model.selectedName == "Home to Work")
    let id = try #require(fixture.store.entries.first?.id)
    await fixture.store.deleteCommute(id: id)

    await fixture.model.reopenIfNeeded()
    #expect(fixture.model.selectedName == "Work to Home")
  }

  @Test func comingBackAfterAddingTheFirstCommuteLeavesTheEmptyState() async {
    let fixture = await makeFixture(commutes: [])
    await fixture.model.open()
    #expect(fixture.model.phase == .empty)
    _ = await fixture.store.addCommute(named: "New", origin: Self.home, destination: Self.work)

    await fixture.model.reopenIfNeeded()
    #expect(fixture.model.phase == .ready)
    #expect(fixture.model.selectedName == "New")
  }

  // MARK: - The location permission

  @Test func anUndecidedUserWithSeveralCommutesIsAskedFirst() async {
    let fixture = await makeFixture(authorization: .notDetermined, at: Self.work)
    await fixture.model.open()
    #expect(fixture.model.phase == .askingPermission)
    #expect(await fixture.service.ran.isEmpty)
    #expect(await fixture.location.requestCount == 0)
  }

  @Test func withOneCommuteThereIsNothingToChooseSoNobodyIsAsked() async {
    let fixture = await makeFixture(
      commutes: [Self.commutes[0]], authorization: .notDetermined, at: Self.work)
    await fixture.model.open()
    #expect(fixture.model.phase == .ready)
    #expect(fixture.model.selectedName == "Home to Work")
    #expect(await fixture.location.requestCount == 0)
  }

  @Test func continuingAsksTheSystemAndThenChoosesByLocation() async {
    let fixture = await makeFixture(authorization: .notDetermined, at: Self.work)
    await fixture.model.open()
    await fixture.model.allowLocation()
    #expect(await fixture.location.requestCount == 1)
    #expect(fixture.model.phase == .ready)
    #expect(fixture.model.selectedName == "Work to Home")
    #expect(fixture.model.reason == .near(originLabel: "Work"))
  }

  @Test func refusingTheSystemPromptFallsBackToTheLastViewed() async {
    let repository = InMemoryConfigRepository(initial: Config(commutes: Self.commutes))
    let store = ConfigStore(repository: repository)
    await store.load()
    let model = HomeModel(
      store: store, service: MockETAService(repository: repository),
      location: FixedLocationProvider(
        authorization: .notDetermined, location: Self.work.latLng, grantsOnRequest: false),
      recents: InMemoryRecentCommutesRepository(initial: ["Home to Gym"]),
      prompts: InMemoryLocationPromptRepository())
    await model.open()
    await model.allowLocation()
    #expect(model.selectedName == "Home to Gym")
    #expect(model.reason == .lastViewed)
  }

  @Test func notNowIsRememberedAndNeverAsksAgain() async {
    let fixture = await makeFixture(authorization: .notDetermined, at: Self.work)
    await fixture.model.open()
    await fixture.model.declineLocation()
    #expect(fixture.model.phase == .ready)
    #expect(fixture.model.reason == .firstInList)
    #expect(await fixture.prompts.wasDeclined())
    #expect(await fixture.location.requestCount == 0)

    await fixture.model.open()
    #expect(fixture.model.phase == .ready)
  }

  @Test func turningLocationOnLaterChoosesAgainEvenIfTheNumbersAreFresh() async {
    // Said "Not now", then enabled it from the Edit screen: Home must not keep its old choice.
    let fixture = await makeFixture(
      authorization: .notDetermined, at: Self.work, declined: true, freshFor: 60)
    await fixture.model.open()
    #expect(fixture.model.selectedName == "Home to Work")
    #expect(fixture.model.reason == .firstInList)

    _ = await fixture.location.requestAuthorization()
    await fixture.model.reopenIfNeeded()
    #expect(fixture.model.selectedName == "Work to Home")
    #expect(fixture.model.reason == .near(originLabel: "Work"))
  }

  @Test func approximateLocationCountsAsNoLocationAndNeverAsks() async {
    let fixture = await makeFixture(authorization: .reducedAccuracy, at: Self.work)
    await fixture.model.open()
    #expect(fixture.model.phase == .ready)
    #expect(fixture.model.reason == .firstInList)
    #expect(await fixture.location.requestCount == 0)
  }

  @Test func aUserWhoAlreadyDeclinedIsNotAskedAtLaunch() async {
    let fixture = await makeFixture(authorization: .notDetermined, at: Self.work, declined: true)
    await fixture.model.open()
    #expect(fixture.model.phase == .ready)
  }
}
