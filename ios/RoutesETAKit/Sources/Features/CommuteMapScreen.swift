import Domain
import MapKit
import SwiftUI

/// One commute: its routes on a full-bleed map, with the trip, the routes and "Show ETAs"
/// in the persistent sheet over it (see `MapSheetScaffold`). The map is read-only: tap a
/// route (on the map or in the list) to find it, and open the route editor to move its
/// via points. ETAs are a companion, fetched only when asked for.
struct CommuteMapScreen: View {
  let store: ConfigStore
  let router: AppRouter
  let placeSearch: any PlaceSearchService
  let savedPlaces: SavedPlacesStore
  let etaService: any ETAService
  /// Schedules only fed the Pi's cron notifications; the standalone app hides them
  /// (the data is kept in the config) until something in the app uses them.
  let showsSchedules: Bool
  let commuteID: CommuteEntry.ID

  private enum Endpoint: String, Identifiable {
    case origin = "From"
    case destination = "To"
    var id: String { rawValue }
  }

  @State private var lines: CommuteLinesModel
  @State private var selectedRoute: String?
  @State private var retries = 0
  @State private var picking: Endpoint?
  @State private var isRenaming = false
  @State private var isConfirmingDelete = false
  @State private var draftName = ""
  @State private var errorMessage: String?
  @State private var isShowingETAs = false
  @State private var pendingRouteDelete: Int?
  @Environment(\.dismiss) private var dismiss

  init(
    store: ConfigStore, router: AppRouter, placeSearch: any PlaceSearchService,
    savedPlaces: SavedPlacesStore, etaService: any ETAService,
    routePreview: any RoutePreviewService, showsSchedules: Bool, commuteID: CommuteEntry.ID
  ) {
    self.store = store
    self.router = router
    self.placeSearch = placeSearch
    self.savedPlaces = savedPlaces
    self.etaService = etaService
    self.showsSchedules = showsSchedules
    self.commuteID = commuteID
    _lines = State(initialValue: CommuteLinesModel(service: routePreview))
  }

  var body: some View {
    if let entry = store.entry(id: commuteID) {
      content(for: entry.commute)
    } else {
      ContentUnavailableView("Commute not found", systemImage: "questionmark.circle")
    }
  }

  // MARK: Map

  private func content(for commute: Commute) -> some View {
    let layer = CommuteMapLayer(commute: commute, lines: lines.lines, selected: selectedRoute)
    return MapSheetScaffold(
      framing: layer.framing,
      isSheetActive: router.path.last == .commute(commuteID),
      accessibilitySummary: layer.summary,
      onTap: { proxy, point in
        // A tap near a line selects its route; a tap on empty map clears the selection.
        selectedRoute = layer.route(near: point) { line in
          line.compactMap { proxy.convert($0.coordinate, to: .global) }
        }
      },
      map: { layer.content },
      sheet: { sheet(for: commute) }
    )
    .overlay(alignment: .top) { banner(for: commute).padding(.top, 8) }
    // The sheet shows the name big; keep it as the title only for the back button.
    .navigationTitle(commute.name)
    .inlineNavigationTitle()
    .hidingNavigationTitle()
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Menu("More", systemImage: "ellipsis.circle") {
          Button("Rename", systemImage: "pencil") {
            draftName = commute.name
            isRenaming = true
          }
          Button("Delete", systemImage: "trash", role: .destructive) {
            isConfirmingDelete = true
          }
        }
      }
    }
    .task(id: LinesKey(commute: commute, retries: retries)) {
      await lines.load(
        origin: commute.origin?.latLng, destination: commute.destination?.latLng,
        vias: commute.routes.map(\.via))
    }
  }

  /// What the lines depend on; `.task(id:)` reloads (cancelling a load in flight) when it changes.
  private struct LinesKey: Hashable {
    var origin: NamedPoint?
    var destination: NamedPoint?
    var vias: [[LatLng]]
    var retries: Int

    init(commute: Commute, retries: Int) {
      origin = commute.origin
      destination = commute.destination
      vias = commute.routes.map(\.via)
      self.retries = retries
    }
  }

  @ViewBuilder private func banner(for commute: Commute) -> some View {
    if commute.origin == nil || commute.destination == nil {
      Label("Set origin and destination to see your routes", systemImage: "mappin.slash")
        .font(.footnote)
        .padding(10)
        .background(.regularMaterial, in: Capsule())
    } else if lines.isLoading && lines.lines.isEmpty {
      ProgressView().padding(8).background(.regularMaterial, in: Capsule())
    } else if lines.failedCount > 0 {
      HStack {
        Text("Couldn't draw \(lines.failedCount) \(lines.failedCount == 1 ? "route" : "routes")")
          .font(.footnote)
        Button("Retry") { retries += 1 }.font(.footnote.bold())
      }
      .padding(10)
      .background(.regularMaterial, in: Capsule())
    }
  }

  // MARK: Sheet

  private func sheet(for commute: Commute) -> some View {
    presentations(for: commute, on: sheetBody(for: commute))
  }

  private func sheetBody(for commute: Commute) -> some View {
    NavigationStack {
      ScrollViewReader { reader in
        list(for: commute)
          .onChange(of: selectedRoute) { _, name in
            if let name { withAnimation { reader.scrollTo(name) } }
          }
      }
      .navigationTitle(commute.name)
      .largeNavigationTitle()
      .toolbar {
        if commute.routes.count > 1 {
          ToolbarItem(placement: .primaryAction) { ReorderButton() }
        }
        ToolbarItem(placement: .primaryAction) {
          Button("Add Route", systemImage: "plus") { Task { await addRoute() } }
            .accessibilityIdentifier("add-route")
        }
      }
    }
  }

  private func list(for commute: Commute) -> some View {
    List {
      Section("Trip") {
        endpointRow(.origin, point: commute.origin)
        endpointRow(.destination, point: commute.destination)
      }

      RoutesSection(
        store: store, router: router, commuteID: commuteID, routes: commute.routes,
        selected: $selectedRoute, pendingDelete: $pendingRouteDelete,
        errorMessage: $errorMessage)

      if showsSchedules {
        Section("Schedule") {
          // A button that pushes through the router: a `NavigationLink(value:)` here would
          // look for its destination in the sheet's own stack, which has none.
          ScheduleRow(schedules: commute.schedules) {
            router.push(.scheduleEditor(commute: commuteID))
          }
        }
      }

      Section {
        Button("Show ETAs", systemImage: "clock") { isShowingETAs = true }
          .disabled(commute.etaBlocker != nil)
          .accessibilityIdentifier("show-etas")
      } footer: {
        if let blocker = commute.etaBlocker { Text(blocker) }
      }
    }
  }

  /// The picker and ETA sheets and the rename/delete/error alerts. They hang off the
  /// sheet's content, not the screen behind it: something presented from a view that is
  /// already presenting a sheet is not shown.
  private func presentations(for commute: Commute, on view: some View) -> some View {
    view
      .sheet(isPresented: $isShowingETAs) { ETASheet(commute: commute, service: etaService) }
      .sheet(item: $picking) { endpoint in
        PlacePickerView(
          title: endpoint.rawValue,
          selected: endpoint == .origin ? commute.origin : commute.destination,
          service: placeSearch,
          savedPlaces: savedPlaces
        ) { place in
          save { commute in
            if endpoint == .origin { commute.origin = place } else { commute.destination = place }
          }
        }
      }
      .alert("Rename Commute", isPresented: $isRenaming) {
        TextField("Name", text: $draftName)
        Button("Rename") { save { $0.name = draftName.trimmingCharacters(in: .whitespaces) } }
        Button("Cancel", role: .cancel) {}
      }
      .alert("Delete \"\(commute.name)\"?", isPresented: $isConfirmingDelete) {
        Button("Delete Commute", role: .destructive) {
          Task {
            errorMessage = await store.deleteCommute(id: commuteID)
            if errorMessage == nil { dismiss() }
          }
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text(commute.deletionWarning)
      }
      .alert(
        "Delete \"\(routeName(at: pendingRouteDelete, in: commute))\"?",
        isPresented: isConfirmingRouteDelete, presenting: pendingRouteDelete
      ) { index in
        Button("Delete Route", role: .destructive) {
          Task { errorMessage = await store.deleteRoute(in: commuteID, at: index) }
        }
        Button("Cancel", role: .cancel) {}
      } message: { index in
        Text(commute.routes.indices.contains(index) ? commute.routes[index].deletionWarning : "")
      }
      .alert("Couldn't save", isPresented: hasError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(errorMessage ?? "")
      }
  }

  private func endpointRow(_ endpoint: Endpoint, point: NamedPoint?) -> some View {
    Button {
      picking = endpoint
    } label: {
      LabeledContent(endpoint.rawValue) {
        Text(point?.label ?? "Not set").foregroundStyle(point == nil ? .secondary : .primary)
      }
    }
    .accessibilityIdentifier("endpoint-\(endpoint.rawValue)")
    .foregroundStyle(.primary)
  }

  private func addRoute() async {
    switch await store.addRoute(to: commuteID) {
    case .success(let index):
      router.push(.routeEditor(commute: commuteID, route: index))
    case .failure(let error):
      errorMessage = error.message
    }
  }

  private func routeName(at index: Int?, in commute: Commute) -> String {
    guard let index, commute.routes.indices.contains(index) else { return "" }
    return commute.routes[index].name
  }

  private var isConfirmingRouteDelete: Binding<Bool> {
    Binding(get: { pendingRouteDelete != nil }, set: { if !$0 { pendingRouteDelete = nil } })
  }

  private var hasError: Binding<Bool> {
    Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
  }

  private func save(_ mutate: @escaping @MainActor (inout Commute) -> Void) {
    Task { errorMessage = await store.updateCommute(id: commuteID, mutate) }
  }
}

/// The schedule summary as a row with a chevron.
private struct ScheduleRow: View {
  let schedules: [ScheduleRule]
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          ForEach(schedules, id: \.self) { Text($0.summary) }
          if schedules.isEmpty { Text("Not scheduled").foregroundStyle(.secondary) }
        }
        Spacer()
        Image(systemName: "chevron.right").font(.footnote.bold()).foregroundStyle(.tertiary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("schedule")
  }
}
