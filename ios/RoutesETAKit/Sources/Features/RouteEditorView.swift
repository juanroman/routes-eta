import Domain
import SwiftUI

/// Name, color and delete for one route. Via points get their map editor in a
/// later slice; for now the screen just reports how many there are.
struct RouteEditorView: View {
  let store: ConfigStore
  let commuteID: CommuteEntry.ID
  let routeIndex: Int

  @State private var draftName = ""
  @State private var loadedName: String?
  @State private var isConfirmingDelete = false
  @State private var errorMessage: String?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    if let commute, let route = commute.routes[safe: routeIndex] {
      form(commute: commute, route: route)
    } else {
      ContentUnavailableView("Route not found", systemImage: "questionmark.circle")
    }
  }

  private var commute: Commute? { store.entry(id: commuteID)?.commute }

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

      Section("Via points") {
        Text("\(route.via.count) via points. Editing them on the map comes next.")
          .foregroundStyle(.secondary)
      }

      Section {
        Button("Delete Route", role: .destructive) { isConfirmingDelete = true }
      }
    }
    .navigationTitle(route.name)
    .inlineNavigationTitle()
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

  private func colorGrid(selected: String) -> some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
      ForEach(RoutePalette.colors, id: \.self) { hex in
        Button {
          Task {
            errorMessage = await store.updateCommute(id: commuteID) {
              if $0.routes.indices.contains(routeIndex) { $0.routes[routeIndex].color = hex }
            }
          }
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
