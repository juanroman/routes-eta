import Domain
import SwiftUI

/// The screen people open the app for: the ETAs of one commute, already chosen, with the same
/// chips as the "Show ETAs" sheet. Editing commutes lives one tap away behind "Edit".
struct HomeView: View {
  let store: ConfigStore
  let router: AppRouter
  let model: HomeModel

  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    content
      .navigationTitle("ETAs")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button("Edit") { router.push(.commutes) }
        }
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
      ContentUnavailableView(
        "No commutes yet", systemImage: "car", description: Text("Tap Edit to add one."))
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

  private var selectedCommute: Commute? {
    store.entries.first { $0.commute.name == model.selectedName }?.commute
  }
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
        HStack {
          Text(binding.wrappedValue).font(.headline)
          Image(systemName: "chevron.down").font(.footnote.bold())
          Spacer()
        }
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

  private func line(_ text: String, symbol: String) -> some View {
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
        failure("Couldn't fetch ETAs.", detail: report.results.compactMap(\.error).first)
      } else {
        // The previous numbers stay while a pull-to-refresh is in flight, dimmed so they are not
        // mistaken for the new ones.
        ETAResultsView(commute: commute, report: report)
          .opacity(model.isRefreshing ? 0.4 : 1)
          .animation(.default, value: model.isRefreshing)
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

/// "Updated 12 seconds ago" on the left, Google's attribution on the right. The attribution has to
/// be in the same container as the data it credits.
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
      Spacer()
      GoogleAttribution()
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
  }
}

/// Google's attribution text for Routes data shown without a Google map: "Google Maps" in a
/// sans-serif face, between 12 and 16 points, not wrapped and not translated.
private struct GoogleAttribution: View {
  @ScaledMetric(relativeTo: .caption) private var scaled: CGFloat = 12

  var body: some View {
    Text(verbatim: "Google Maps")
      .font(.system(size: min(max(scaled, 12), 16)))
      .foregroundStyle(.secondary)
      .lineLimit(1)
      .fixedSize()
      .accessibilityIdentifier("google-attribution")
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
