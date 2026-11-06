import Domain
import SwiftUI

/// One route: its map (add/move/remove via points), name, color and delete.
struct RouteEditorView: View {
  let store: ConfigStore
  let routePreview: any RoutePreviewService
  let commuteID: CommuteEntry.ID
  let routeIndex: Int

  @State private var model: RouteMapModel
  @State private var selectedVia: Int?
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
      viaBar(route: route)
      form(commute: commute, route: route)
    }
    .navigationTitle(route.name)
    .inlineNavigationTitle()
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
      ZStack(alignment: .top) {
        RouteMapView(
          origin: origin, destination: destination, color: Color(hex: route.color),
          via: route.via, polyline: model.polyline, selectedVia: $selectedVia,
          onAdd: { add($0, to: route) },
          onMove: { index, point in
            edit { $0.moveVia(at: index, to: point) }
          })
        statusBanner
      }
    } else {
      ContentUnavailableView(
        "Set origin and destination first", systemImage: "mappin.slash",
        description: Text("The route is drawn between them. Set them on the commute screen."))
    }
  }

  @ViewBuilder private var statusBanner: some View {
    switch model.status {
    case .loading:
      ProgressView().padding(8).background(.regularMaterial, in: Capsule()).padding(8)
    case .failed:
      VStack(spacing: 6) {
        Text(model.failureMessage ?? "Couldn't draw the route")
          .font(.footnote)
          .multilineTextAlignment(.center)
          .lineLimit(4)
        Button("Retry") { retry() }
          .font(.subheadline.bold())
      }
      .padding(10)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
      .padding(8)
    case .idle, .loaded:
      EmptyView()
    }
  }

  private func viaBar(route: RouteDef) -> some View {
    HStack {
      Text(viaSummary(route.via.count))
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("via-count")
      Spacer()
      if let selected = selectedVia, route.via.indices.contains(selected) {
        Button("Remove via point \(selected + 1)", role: .destructive) {
          edit { $0.removeVia(at: selected) }
          selectedVia = nil
        }
        .accessibilityIdentifier("remove-via")
      } else if route.canAddVia {
        Text("Tap the route to add a via point").font(.footnote).foregroundStyle(.secondary)
      } else {
        Text("Maximum of \(maxViaPoints) via points").font(.footnote).foregroundStyle(.orange)
      }
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
  }

  private func viaSummary(_ count: Int) -> String {
    switch count {
    case 0: "No via points"
    case 1: "1 via point"
    default: "\(count) via points"
    }
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
