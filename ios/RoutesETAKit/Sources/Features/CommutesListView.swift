import Domain
import SwiftUI

struct CommutesListView: View {
  let store: ConfigStore

  @State private var isAdding = false
  @State private var renaming: CommuteEntry.ID?
  @State private var pendingDelete: CommuteEntry?
  @State private var draftName = ""
  @State private var errorMessage: String?

  var body: some View {
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
      ToolbarItem(placement: .primaryAction) {
        Button("Add Commute", systemImage: "plus") {
          draftName = ""
          isAdding = true
        }
      }
    }
    .alert("New Commute", isPresented: $isAdding) {
      TextField("Name", text: $draftName)
      Button("Add") { submit { await store.addCommute(named: draftName) } }
      Button("Cancel", role: .cancel) {}
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
      Text(deleteWarning(for: entry.commute))
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

  private func deleteWarning(for commute: Commute) -> String {
    let count = commute.routes.count
    guard count > 0 else { return "This can't be undone." }
    return "Its \(count) \(count == 1 ? "route" : "routes") and schedule will be deleted too."
  }

  private var hasError: Binding<Bool> {
    Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
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
