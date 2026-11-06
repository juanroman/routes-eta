import Domain
import MapKit
import SwiftUI

/// One route: its map (add/move/remove via points), name, color and delete.
struct RouteEditorView: View {
  let store: ConfigStore
  let routePreview: any RoutePreviewService
  let commuteID: CommuteEntry.ID
  let routeIndex: Int

  @State private var model: RouteMapModel
  @State private var selectedVia: Int?
  @State private var cameraRegion: MKCoordinateRegion?
  @State private var isFullScreen = false
  @State private var draftName = ""
  @State private var loadedName: String?
  @State private var isConfirmingDelete = false
  @State private var errorMessage: String?
  @Environment(\.dismiss) private var dismiss

  init(
    store: ConfigStore, routePreview: any RoutePreviewService, commuteID: CommuteEntry.ID,
    routeIndex: Int
  ) {
    self.store = store
    self.routePreview = routePreview
    self.commuteID = commuteID
    self.routeIndex = routeIndex
    _model = State(initialValue: RouteMapModel(service: routePreview))
  }

  /// What the preview depends on; `.task(id:)` re-runs (cancelling any request in
  /// flight) whenever it changes.
  private struct PreviewKey: Hashable {
    var origin: NamedPoint?
    var destination: NamedPoint?
    var via: [LatLng]
  }

  var body: some View {
    if let commute, let route = commute.routes[safe: routeIndex] {
      content(commute: commute, route: route)
    } else {
      ContentUnavailableView("Route not found", systemImage: "questionmark.circle")
    }
  }

  private func previewKey(commute: Commute, route: RouteDef) -> PreviewKey {
    PreviewKey(origin: commute.origin, destination: commute.destination, via: route.via)
  }

  private var commute: Commute? { store.entry(id: commuteID)?.commute }

  private func content(commute: Commute, route: RouteDef) -> some View {
    VStack(spacing: 0) {
      mapArea(commute: commute, route: route)
        .frame(height: 340)
      ViaBar(route: route, selectedVia: $selectedVia) { index in
        edit { $0.removeVia(at: index) }
      }
      form(commute: commute, route: route)
    }
    .navigationTitle(route.name)
    .inlineNavigationTitle()
    .fullScreenCoverOnIOS(isPresented: $isFullScreen) {
      fullScreenMap(commute: commute, route: route)
    }
    .task(id: previewKey(commute: commute, route: route)) {
      guard let origin = commute.origin, let destination = commute.destination else { return }
      await model.load(origin: origin.latLng, destination: destination.latLng, via: route.via)
    }
    .onAppear {
      if loadedName == nil {
        draftName = route.name
        loadedName = route.name
      }
    }
    .onDisappear { Task { await commitName(in: commute) } }
    .alert("Delete \"\(route.name)\"?", isPresented: $isConfirmingDelete) {
      Button("Delete Route", role: .destructive) {
        Task {
          errorMessage = await store.deleteRoute(in: commuteID, at: routeIndex)
          if errorMessage == nil { dismiss() }
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(route.deletionWarning)
    }
    .alert("Couldn't save", isPresented: hasError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage ?? "")
    }
  }

  // MARK: Map

  @ViewBuilder
  private func mapArea(commute: Commute, route: RouteDef) -> some View {
    if let origin = commute.origin, let destination = commute.destination {
      mapEditor(origin: origin, destination: destination, route: route, expanded: false)
    } else {
      ContentUnavailableView(
        "Set origin and destination first", systemImage: "mappin.slash",
        description: Text("The route is drawn between them. Set them on the commute screen."))
    }
  }

  @ViewBuilder
  private func fullScreenMap(commute: Commute, route: RouteDef) -> some View {
    if let origin = commute.origin, let destination = commute.destination {
      ZStack(alignment: .bottom) {
        mapEditor(origin: origin, destination: destination, route: route, expanded: true)
        ViaBar(route: route, selectedVia: $selectedVia) { index in
          edit { $0.removeVia(at: index) }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
      }
    }
  }

  private func mapEditor(
    origin: NamedPoint, destination: NamedPoint, route: RouteDef, expanded: Bool
  ) -> some View {
    RouteMapEditor(
      origin: origin, destination: destination, route: route, model: model,
      selectedVia: $selectedVia, cameraRegion: $cameraRegion, isFullScreen: expanded,
      onAdd: { add($0, to: route) },
      onMove: { index, point in edit { $0.moveVia(at: index, to: point) } },
      onRetry: { retry() },
      onToggleFullScreen: { isFullScreen.toggle() })
  }

  private func add(_ point: LatLng, to route: RouteDef) {
    guard route.canAddVia else { return }
    let polyline = model.polyline
    Task {
      var inserted: Int?
      errorMessage = await store.updateCommute(id: commuteID) {
        if $0.routes.indices.contains(routeIndex) {
          inserted = $0.routes[routeIndex].addVia(at: point, along: polyline)
        }
      }
      selectedVia = inserted
    }
  }

  /// Applies a change to this route through the store's validated write path.
  private func edit(_ change: @escaping @MainActor (inout RouteDef) -> Void) {
    Task {
      errorMessage = await store.updateCommute(id: commuteID) {
        if $0.routes.indices.contains(routeIndex) { change(&$0.routes[routeIndex]) }
      }
    }
  }

  private func retry() {
    guard let commute, let route = commute.routes[safe: routeIndex],
      let origin = commute.origin, let destination = commute.destination
    else { return }
    Task {
      await model.load(origin: origin.latLng, destination: destination.latLng, via: route.via)
    }
  }

  // MARK: Form

  private func form(commute: Commute, route: RouteDef) -> some View {
    Form {
      Section {
        TextField("Name", text: $draftName)
          .onSubmit { Task { await commitName(in: commute) } }
          .accessibilityIdentifier("route-name")
      } header: {
        Text("Name")
      } footer: {
        if let problem = commute.routeNameProblem(draftName, at: routeIndex) {
          Text(problem.description).foregroundStyle(.red)
        }
      }

      Section("Color") { colorGrid(selected: route.color) }

      Section {
        Button("Delete Route", role: .destructive) { isConfirmingDelete = true }
      }
    }
  }

  private func colorGrid(selected: String) -> some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
      ForEach(RoutePalette.colors, id: \.self) { hex in
        Button {
          edit { $0.color = hex }
        } label: {
          Circle()
            .fill(Color(hex: hex))
            .frame(width: 36, height: 36)
            .overlay {
              if hex.lowercased() == selected.lowercased() {
                Image(systemName: "checkmark").foregroundStyle(.white).bold()
              }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Color \(hex)")
        .accessibilityIdentifier("color-\(hex)")
      }
    }
    .padding(.vertical, 4)
  }

  /// Applies the draft name if it is valid and changed; an invalid draft is
  /// left showing its inline error and the saved name stays as it was.
  private func commitName(in commute: Commute) async {
    let trimmed = draftName.trimmingCharacters(in: .whitespaces)
    guard commute.routes.indices.contains(routeIndex),
      commute.routes[routeIndex].name != trimmed,
      commute.routeNameProblem(draftName, at: routeIndex) == nil
    else { return }
    errorMessage = await store.updateCommute(id: commuteID) {
      if $0.routes.indices.contains(routeIndex) { $0.routes[routeIndex].name = trimmed }
    }
  }

  private var hasError: Binding<Bool> {
    Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
  }
}

extension Array {
  fileprivate subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
