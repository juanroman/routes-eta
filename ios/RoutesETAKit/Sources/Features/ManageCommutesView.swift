import Domain
import SwiftUI

/// "Manage Commutes", a sheet from Home's ⋯ menu: the order of the commutes (always in reorder
/// mode, since that is all the list is for) and what the app does with location. Renaming and
/// deleting a commute happen on its own screen; adding one has its own form.
struct ManageCommutesView: View {
  let store: ConfigStore
  let location: any LocationProvider

  @State private var errorMessage: String?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Section("Order") {
          ForEach(store.entries) { entry in
            CommuteRow(commute: entry.commute)
          }
          .onMove { source, destination in
            Task { errorMessage = await store.moveCommute(from: source, to: destination) }
          }
        }
        LocationSettingSection(location: location)
      }
      .alwaysReordering()
      .navigationTitle("Manage Commutes")
      .inlineNavigationTitle()
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
      }
      .alert("Couldn't save", isPresented: hasError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(errorMessage ?? "")
      }
    }
  }

  private var hasError: Binding<Bool> {
    Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
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

  private var subtitle: LocalizedStringKey {
    let from = commute.origin?.label ?? "?"
    let to = commute.destination?.label ?? "?"
    let count = commute.routes.count
    return count == 1 ? "\(from) → \(to) · 1 route" : "\(from) → \(to) · \(count) routes"
  }
}
