import Domain
import Foundation
import Observation

/// What the Home view shows: the ETAs of one commute, chosen for the user.
///
/// On open it asks `HomeSelection` which commute to show (the one that starts where the user is,
/// else the last viewed), and fetches only that one. Every fetch is fresh and nothing is kept:
/// the ETAs live in the `ETAModel` for the commute on screen and vanish with it, so choosing
/// another commute can never show the previous one's numbers.
@MainActor
@Observable
final class HomeModel {
  enum Phase: Equatable {
    /// Waiting for the store, the user's location, or the choice of commute.
    case resolving
    /// There are no commutes to show.
    case empty
    /// Explaining why location is wanted, before the system asks.
    case askingPermission
    /// A commute is on screen; `eta` holds its state.
    case ready
  }

  private(set) var phase: Phase = .resolving
  private(set) var selectedName: String?
  /// Why that commute was chosen; nil when the user picked it themselves.
  private(set) var reason: HomeSelection.Reason?
  private(set) var eta: ETAModel?

  private let store: ConfigStore
  private let service: any ETAService
  private let location: any LocationProvider
  private let recents: any RecentCommutesRepository
  private let prompts: any LocationPromptRepository
  private let locationTimeout: Duration
  private let freshFor: TimeInterval

  /// The commute as it was when fetched, to notice that it was edited meanwhile.
  private var shownCommute: Commute?
  /// The location permission when the commute was chosen: if it changes (turned on from the Edit
  /// screen, or in Settings) the choice is made again even when the ETAs are fresh.
  private var chosenWith: LocationAuthorization?
  private var isOpening = false
  private var loading: Task<Void, Never>?

  /// - Parameters:
  ///   - locationTimeout: How long to wait for a location before choosing without one.
  ///   - freshFor: Coming back to the screen within this many seconds of a fetch (and with the
  ///     commute unchanged) doesn't fetch again; it absorbs the app going inactive for the
  ///     system's permission alert.
  init(
    store: ConfigStore, service: any ETAService, location: any LocationProvider,
    recents: any RecentCommutesRepository, prompts: any LocationPromptRepository,
    locationTimeout: Duration = .seconds(3), freshFor: TimeInterval = 5
  ) {
    self.store = store
    self.service = service
    self.location = location
    self.recents = recents
    self.prompts = prompts
    self.locationTimeout = locationTimeout
    self.freshFor = freshFor
  }

  /// Chooses the commute and fetches its ETAs. Call once the store has loaded.
  func open() async {
    guard !isOpening else { return }
    isOpening = true
    defer { isOpening = false }

    let entries = store.entries
    guard !entries.isEmpty else {
      showNothing()
      return
    }
    phase = .resolving
    let recent = (try? await recents.load()) ?? []
    let authorization = await location.authorization()
    chosenWith = authorization

    // With one commute there is nothing to choose, so location is not worth asking for.
    if entries.count > 1, authorization == .notDetermined {
      let declined = await prompts.wasDeclined()
      if !declined {
        phase = .askingPermission
        return
      }
    }
    let here: LatLng? =
      authorization == .authorized ? await location.currentLocation(timeout: locationTimeout) : nil
    guard
      let pick = HomeSelection.pick(commutes: entries.map(\.commute), recent: recent, here: here)
    else {
      showNothing()
      return
    }
    await show(pick.name, reason: pick.reason, recent: recent)
  }

  /// The user picked a commute: show it, and let the choice count as "viewed".
  func select(_ name: String) async {
    guard name != selectedName else { return }
    let recent = (try? await recents.load()) ?? []
    await show(name, reason: nil, recent: recent)
  }

  /// Pull-to-refresh: the numbers on screen stay (dimmed) until the new ones arrive.
  func refresh() async {
    await eta?.refresh()
  }

  /// "Try Again" after a failure.
  func retry() async {
    await eta?.load()
  }

  /// The app came back to the foreground, or the user returned from editing: fetch again,
  /// unless nothing changed and the ETAs are only seconds old.
  func reopenIfNeeded() async {
    switch phase {
    case .askingPermission, .resolving:
      return
    case .empty:
      await open()
      return
    case .ready:
      break
    }
    guard
      let name = selectedName, let eta,
      let current = store.entries.first(where: { $0.commute.name == name })?.commute,
      current == shownCommute, await location.authorization() == chosenWith
    else {
      await open()
      return
    }
    switch eta.state {
    case .loading:
      return
    case .loaded(_, let fetchedAt) where Date().timeIntervalSince(fetchedAt) < freshFor:
      return
    default:
      await open()
    }
  }

  /// "Continue" on the explanation: show the system prompt, then choose with the answer.
  func allowLocation() async {
    _ = await location.requestAuthorization()
    await open()
  }

  /// "Not now" on the explanation: never ask again, and choose without a location.
  func declineLocation() async {
    await prompts.markDeclined()
    await open()
  }

  private func show(_ name: String, reason: HomeSelection.Reason?, recent: [String]) async {
    loading?.cancel()
    let model = ETAModel(service: service, commuteName: name)
    eta = model
    selectedName = name
    self.reason = reason
    shownCommute = store.entries.first { $0.commute.name == name }?.commute
    phase = .ready

    let task = Task { await model.load() }
    loading = task
    try? await recents.save(RecentCommutes.touch(name, in: recent))
    await task.value
  }

  private func showNothing() {
    loading?.cancel()
    phase = .empty
    selectedName = nil
    reason = nil
    eta = nil
    shownCommute = nil
    chosenWith = nil
  }
}
