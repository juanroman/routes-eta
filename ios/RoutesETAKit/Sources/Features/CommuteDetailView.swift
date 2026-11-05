import Domain
import SwiftUI

struct CommuteDetailView: View {
  let store: ConfigStore
  let placeSearch: any PlaceSearchService
  let savedPlaces: SavedPlacesStore
  let commuteID: CommuteEntry.ID

  private enum Endpoint: String, Identifiable {
    case origin = "From"
    case destination = "To"
    var id: String { rawValue }
  }

  @State private var picking: Endpoint?
  @State private var isRenaming = false
  @State private var isConfirmingDelete = false
  @State private var draftName = ""
  @State private var errorMessage: String?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    if let entry = store.entry(id: commuteID) {
      content(for: entry.commute)
    } else {
      ContentUnavailableView("Commute not found", systemImage: "questionmark.circle")
    }
  }

  private func content(for commute: Commute) -> some View {
    presentations(for: commute, on: list(for: commute))
      .navigationTitle(commute.name)
      .inlineNavigationTitle()
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
  }

  private func list(for commute: Commute) -> some View {
    List {
      Section("Trip") {
        endpointRow(.origin, point: commute.origin)
        endpointRow(.destination, point: commute.destination)
      }

      Section("Routes") {
        ForEach(commute.routes, id: \.name) { route in
          NavigationLink(value: AppRoute.routeEditor(commute: commuteID, routeName: route.name)) {
            HStack {
              Circle().fill(Color(hex: route.color)).frame(width: 14, height: 14)
              Text(route.name)
              Spacer()
              Text("\(route.via.count) via").foregroundStyle(.secondary)
            }
          }
        }
        if commute.routes.isEmpty {
          Text("No routes yet").foregroundStyle(.secondary)
        }
      }

      Section("Schedule") {
        NavigationLink(value: AppRoute.scheduleEditor(commute: commuteID)) {
          VStack(alignment: .leading, spacing: 2) {
            ForEach(commute.schedules, id: \.self) { Text($0.summary) }
            if commute.schedules.isEmpty {
              Text("Not scheduled").foregroundStyle(.secondary)
            }
          }
        }
      }

      Section {
        // Wired to ETAService in Phase 3.
        Button("Show ETAs", systemImage: "clock") {}
          .disabled(true)
      }
    }
  }

  /// The picker sheet and the rename/delete/error alerts.
  private func presentations(for commute: Commute, on view: some View) -> some View {
    view
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

  private var hasError: Binding<Bool> {
    Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
  }

  private func save(_ mutate: @escaping @MainActor (inout Commute) -> Void) {
    Task { errorMessage = await store.updateCommute(id: commuteID, mutate) }
  }
}
