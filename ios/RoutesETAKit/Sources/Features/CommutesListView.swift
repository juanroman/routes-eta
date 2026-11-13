import Domain
import SwiftUI

struct CommutesListView: View {
  let store: ConfigStore
  let router: AppRouter
  let placeSearch: any PlaceSearchService
  let savedPlaces: SavedPlacesStore
  let location: any LocationProvider

  @State private var isAdding = false
  /// The commute the form just created. It is opened once the form has finished closing:
  /// a push while a sheet is still dismissing gets dropped.
  @State private var createdCommute: CommuteEntry.ID?
  @State private var renaming: CommuteEntry.ID?
  @State private var pendingDelete: CommuteEntry?
  @State private var draftName = ""
  @State private var errorMessage: String?

  var body: some View {
    presentations(on: content)
  }

  private var content: some View {
    Group {
      switch store.loadState {
      case .idle, .loading:
        ProgressView()
      case .failed(let message):
        ContentUnavailableView(message, systemImage: "exclamationmark.triangle")
      case .loaded:
        list
      }
    }
    .navigationTitle("Commutes")
    .toolbar {
      if store.entries.count > 1 {
        ToolbarItem(placement: .primaryAction) { ReorderButton() }
      }
      ToolbarItem(placement: .primaryAction) {
        Button("Add Commute", systemImage: "plus") { isAdding = true }
      }
    }
  }

  private func presentations(on view: some View) -> some View {
    view
      .sheet(isPresented: $isAdding, onDismiss: openCreatedCommute) {
        NewCommuteView(store: store, placeSearch: placeSearch, savedPlaces: savedPlaces) { id in
          createdCommute = id
        }
      }
      .alert("Rename Commute", isPresented: isRenaming) {
        TextField("Name", text: $draftName)
        Button("Rename") {
          guard let id = renaming else { return }
          submit { await store.renameCommute(id: id, to: draftName) }
        }
        Button("Cancel", role: .cancel) {}
      }
      .alert(
        "Delete \"\(pendingDelete?.commute.name ?? "")\"?",
        isPresented: isConfirmingDelete,
        presenting: pendingDelete
      ) { entry in
        Button("Delete Commute", role: .destructive) {
          submit { await store.deleteCommute(id: entry.id) }
        }
        Button("Cancel", role: .cancel) {}
      } message: { entry in
        Text(entry.commute.deletionWarning)
      }
      .alert("Couldn't save", isPresented: hasError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(errorMessage ?? "")
      }
  }

  private var list: some View {
    List {
      ForEach(store.entries) { entry in
        NavigationLink(value: AppRoute.commute(entry.id)) {
          CommuteRow(commute: entry.commute)
        }
        .swipeActions {
          Button("Delete", role: .destructive) { pendingDelete = entry }
          Button("Rename") {
            draftName = entry.commute.name
            renaming = entry.id
          }
        }
      }
      .onMove { source, destination in
        Task { errorMessage = await store.moveCommute(from: source, to: destination) }
      }
      // With one commute there is nothing for location to choose between.
      if store.entries.count > 1 { LocationSettingSection(location: location) }
    }
    .overlay {
      if store.entries.isEmpty {
        ContentUnavailableView(
          "No commutes yet", systemImage: "car", description: Text("Tap + to add one."))
      }
    }
  }

  private var isRenaming: Binding<Bool> {
    Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
  }

  private var isConfirmingDelete: Binding<Bool> {
    Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
  }

  private var hasError: Binding<Bool> {
    Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
  }

  private func openCreatedCommute() {
    guard let id = createdCommute else { return }
    createdCommute = nil
    router.push(.commute(id))
  }

  private func submit(_ action: @escaping @MainActor () async -> String?) {
    Task { errorMessage = await action() }
  }
}

private struct CommuteRow: View {
  let commute: Commute

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(commute.name).font(.headline)
      Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
    }
  }

  private var subtitle: String {
    let from = commute.origin?.label ?? "?"
    let to = commute.destination?.label ?? "?"
    let count = commute.routes.count
    return "\(from) → \(to) · \(count) \(count == 1 ? "route" : "routes")"
  }
}
