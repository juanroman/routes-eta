import Domain
import SwiftUI

/// The screen people open the app for: the ETAs of one commute, already chosen, with the same
/// chips for each route. The commute on screen is also the one "Details" opens (its map and
/// routes); adding a commute and putting them in order are sheets from the ⋯ menu.
struct HomeView: View {
  let store: ConfigStore
  let router: AppRouter
  let model: HomeModel
  let placeSearch: any PlaceSearchService
  let savedPlaces: SavedPlacesStore
  let location: any LocationProvider

  @State private var isAdding = false
  @State private var isManaging = false
  /// The commute the form just created. It is shown once the form has finished closing:
  /// a push while a sheet is still dismissing gets dropped.
  @State private var createdCommute: CommuteEntry.ID?

  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    content
      .navigationTitle("ETAs")
      .toolbar { toolbar }
      .sheet(isPresented: $isAdding, onDismiss: openCreatedCommute) {
        NewCommuteView(store: store, placeSearch: placeSearch, savedPlaces: savedPlaces) { id in
          createdCommute = id
        }
      }
      // Location may have been turned on there, which changes which commute Home picks.
      .sheet(isPresented: $isManaging) {
        ManageCommutesView(store: store, location: location)
          .onDisappear { Task { await model.reopenIfNeeded() } }
      }
      // Once the store has loaded: choose the commute and fetch its ETAs.
      .task(id: store.loadState) {
        if store.loadState == .loaded { await model.open() }
      }
      .onChange(of: scenePhase) { _, phase in
        if phase == .active { Task { await model.reopenIfNeeded() } }
      }
      // Back from editing: the commute may have been renamed, deleted or given other routes.
      .onChange(of: router.path.isEmpty) { _, isEmpty in
        if isEmpty { Task { await model.reopenIfNeeded() } }
      }
  }

  @ToolbarContentBuilder private var toolbar: some ToolbarContent {
    if let selected = selectedEntry, model.phase == .ready {
      ToolbarItem(placement: .primaryAction) {
        Button("Details") { router.push(.commute(selected.id)) }
          .accessibilityIdentifier("home-details")
      }
    }
    ToolbarItem(placement: .primaryAction) {
      Menu("More", systemImage: "ellipsis.circle") {
        Button("Add Commute…", systemImage: "plus") { isAdding = true }
          .accessibilityIdentifier("home-add")
        // With one commute there is no order to change and no commute for location to choose.
        if store.entries.count > 1 {
          Button("Manage Commutes…", systemImage: "arrow.up.arrow.down") { isManaging = true }
            .accessibilityIdentifier("home-manage")
        }
      }
      .accessibilityIdentifier("home-more")
    }
  }

  /// The new commute becomes the one on screen, then opens so its routes can be set.
  private func openCreatedCommute() {
    guard let id = createdCommute else { return }
    createdCommute = nil
    guard let name = store.entry(id: id)?.commute.name else { return }
    Task {
      await model.select(name)
      router.push(.commute(id))
    }
  }

  @ViewBuilder private var content: some View {
    switch store.loadState {
    case .idle, .loading:
      checking
    case .failed(let message):
      ContentUnavailableView(message, systemImage: "exclamationmark.triangle")
    case .loaded:
      loaded
    }
  }

  @ViewBuilder private var loaded: some View {
    switch model.phase {
    case .resolving:
      checking
    case .empty:
      ContentUnavailableView {
        Label("No commutes yet", systemImage: "car")
      } description: {
        Text("Add the trip you make most, and Home will show its ETAs.")
      } actions: {
        Button("Add Commute") { isAdding = true }
          .buttonStyle(.borderedProminent)
          .accessibilityIdentifier("home-add-commute")
      }
    case .askingPermission:
      LocationExplainer(
        allow: { Task { await model.allowLocation() } },
        decline: { Task { await model.declineLocation() } })
    case .ready:
      ready
    }
  }

  private var checking: some View {
    ProgressView("Checking traffic…").frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder private var ready: some View {
    VStack(spacing: 0) {
      if store.entries.count > 1 {
        CommuteSelector(
          names: store.entries.map(\.commute.name), selected: model.selectedName,
          select: { name in Task { await model.select(name) } }
        )
        .padding(.horizontal)
      }
      ReasonLine(reason: model.reason)
      if let eta = model.eta, let commute = selectedCommute {
        HomeETAContent(
          model: eta, commute: commute, refresh: { await model.refresh() },
          retry: { await model.retry() })
      }
    }
  }

  private var selectedEntry: CommuteEntry? {
    store.entries.first { $0.commute.name == model.selectedName }
  }

  private var selectedCommute: Commute? { selectedEntry?.commute }
}

/// Segments for a few commutes; a menu once they would not fit (many commutes, or large type).
private struct CommuteSelector: View {
  let names: [String]
  let selected: String?
  let select: @Sendable (String) -> Void

  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    let binding = Binding(get: { selected ?? names.first ?? "" }, set: select)
    if names.count <= 3 && !typeSize.isAccessibilitySize {
      Picker("Commute", selection: binding) {
        ForEach(names, id: \.self) { Text($0).tag($0) }
      }
      .pickerStyle(.segmented)
      .accessibilityIdentifier("home-selector")
    } else {
      Menu {
        Picker("Commute", selection: binding) {
          ForEach(names, id: \.self) { Text($0).tag($0) }
        }
      } label: {
        // One piece of text, so the chevron stays at the end of the name even when it wraps.
        Text("\(binding.wrappedValue) \(Image(systemName: "chevron.down"))")
          .font(.headline)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .accessibilityIdentifier("home-selector")
    }
  }
}

/// "Near Home" / "Last viewed": says why this commute is the one on screen.
private struct ReasonLine: View {
  let reason: HomeSelection.Reason?

  var body: some View {
    switch reason {
    case .near(let label):
      line("Near \(label)", symbol: "location.fill")
    case .lastViewed:
      line("Last viewed", symbol: "clock")
    case .firstInList, nil:
      EmptyView()
    }
  }

  private func line(_ text: LocalizedStringKey, symbol: String) -> some View {
    Label(text, systemImage: symbol)
      .font(.footnote)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal)
      .padding(.top, 10)
      .accessibilityIdentifier("home-reason")
  }
}

/// The chips for the commute on screen, with pull-to-refresh and the freshness footer.
private struct HomeETAContent: View {
  let model: ETAModel
  let commute: Commute
  let refresh: () async -> Void
  let retry: () async -> Void

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        stateContent(model.state)
          .padding()
      }
      // Always bounce, even when the few chips don't fill the screen: otherwise there is
      // nothing to pull and pull-to-refresh never starts.
      .scrollBounceBehavior(.always)
      .refreshable { await refresh() }
      .accessibilityIdentifier("eta-results")
      if case .loaded(let report, let fetchedAt) = model.state, !report.allFailed {
        Footer(fetchedAt: fetchedAt)
      }
    }
  }

  @ViewBuilder private func stateContent(_ state: ETAModel.State) -> some View {
    switch state {
    case .idle, .loading:
      ProgressView("Checking traffic…")
        .frame(maxWidth: .infinity, minHeight: 240)
    case .failed(let message):
      failure(message)
    case .loaded(let report, _):
      if report.allFailed {
        failure(
          String(localized: "Couldn't fetch ETAs."),
          detail: report.results.compactMap(\.error).first)
      } else {
        // The previous numbers stay while a pull-to-refresh is in flight, dimmed so they are not
        // mistaken for the new ones.
        ETACard(commute: commute, report: report, isDimmed: model.isRefreshing)
      }
    }
  }

  private func failure(_ message: String, detail: String? = nil) -> some View {
    ContentUnavailableView {
      Label(message, systemImage: "exclamationmark.triangle")
    } description: {
      if let detail { Text(detail) }
    } actions: {
      Button("Try Again") { Task { await retry() } }
        .accessibilityIdentifier("eta-retry")
    }
  }
}

/// "Updated 12 seconds ago". Ours, so it sits outside the card that holds Google's data.
private struct Footer: View {
  let fetchedAt: Date

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      TimelineView(RelativeAgeSchedule(since: fetchedAt)) { context in
        Text("Updated \(RelativeAge.text(since: fetchedAt, now: context.date))")
          .accessibilityIdentifier("home-updated")
      }
      .font(.footnote)
      .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal)
    .padding(.vertical, 8)
  }
}

/// Shown once, before the system prompt, so the request makes sense when it arrives.
private struct LocationExplainer: View {
  let allow: () -> Void
  let decline: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "location.circle.fill")
        .font(.system(size: 56))
        .foregroundStyle(.tint)
      Text("Show the commute that starts where you are")
        .font(.title2.bold())
        .multilineTextAlignment(.center)
      Text("Your location stays on this device. It's only used to pick which commute to show.")
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      Button("Continue", action: allow)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityIdentifier("location-continue")
      Button("Not now", action: decline)
        .accessibilityIdentifier("location-not-now")
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
