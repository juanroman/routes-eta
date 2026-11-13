import Domain
import SwiftUI

/// The form behind "Add Commute": a name and both places. The places are chosen here, once,
/// so a commute never exists without something to draw; afterwards they only show up when
/// you press Edit on the commute. Add stays disabled until the name and both places are set.
struct NewCommuteView: View {
  let store: ConfigStore
  let placeSearch: any PlaceSearchService
  let savedPlaces: SavedPlacesStore
  /// Called with the new commute's id once it is saved, just before the form closes.
  let onCreated: (CommuteEntry.ID) -> Void

  private enum Endpoint: String, Identifiable {
    case origin = "From"
    case destination = "To"
    var id: String { rawValue }
  }

  @State private var name = ""
  @State private var origin: NamedPoint?
  @State private var destination: NamedPoint?
  @State private var picking: Endpoint?
  @State private var isSaving = false
  @State private var errorMessage: String?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Name", text: $name).accessibilityIdentifier("commute-name")
        }
        Section("Trip") {
          endpointRow(.origin, point: origin)
          endpointRow(.destination, point: destination)
        }
      }
      .navigationTitle("New Commute")
      .inlineNavigationTitle()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") { Task { await add() } }
            .disabled(!canAdd)
            .accessibilityIdentifier("add-commute-confirm")
        }
      }
      .sheet(item: $picking) { endpoint in
        PlacePickerView(
          title: endpoint.rawValue,
          selected: endpoint == .origin ? origin : destination,
          service: placeSearch,
          savedPlaces: savedPlaces
        ) { place in
          if endpoint == .origin { origin = place } else { destination = place }
        }
      }
      .alert("Couldn't save", isPresented: hasError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(errorMessage ?? "")
      }
    }
  }

  private var canAdd: Bool {
    !name.trimmingCharacters(in: .whitespaces).isEmpty && origin != nil && destination != nil
      && !isSaving
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

  private func add() async {
    isSaving = true
    switch await store.addCommute(named: name, origin: origin, destination: destination) {
    case .success(let id):
      onCreated(id)
      dismiss()
    case .failure(let error):
      errorMessage = error.message
      isSaving = false
    }
  }

  private var hasError: Binding<Bool> {
    Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
  }
}
