import Domain
import SwiftUI

/// Origin/destination picker modeled on Calendar's Location field (search with
/// name + address results) and Maps' Places row (Home / Work shortcuts).
struct PlacePickerView: View {
  let title: String
  let selected: NamedPoint?
  let savedPlaces: SavedPlacesStore
  let onSelect: (NamedPoint?) -> Void

  @State private var model: PlacePickerModel
  @State private var query = ""
  /// Set while the user is choosing the address for an unset (or changing) shortcut.
  @State private var assigning: SavedPlaceKind?
  @Environment(\.dismiss) private var dismiss

  init(
    title: String, selected: NamedPoint?, service: any PlaceSearchService,
    savedPlaces: SavedPlacesStore, onSelect: @escaping (NamedPoint?) -> Void
  ) {
    self.title = title
    self.selected = selected
    self.savedPlaces = savedPlaces
    self.onSelect = onSelect
    _model = State(initialValue: PlacePickerModel(service: service))
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          HStack(alignment: .top, spacing: 24) {
            ForEach(SavedPlaceKind.allCases, id: \.self) { kind in shortcut(kind) }
            Spacer()
          }
          .listRowBackground(Color.clear)
        } footer: {
          if let kind = assigning {
            Text("Search for your \(kind.label) address.")
          }
        }

        if selected != nil {
          Button("Clear \(title)", role: .destructive) { choose(nil) }
        }

        results
      }
      .searchable(text: $query, prompt: "Search places")
      .task(id: query) { await model.update(query: query) }
      .navigationTitle(title)
      .inlineNavigationTitle()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
      .alert("Couldn't find that place", isPresented: resolveFailed) {
        Button("OK", role: .cancel) {}
      }
    }
  }

  @ViewBuilder private var results: some View {
    if model.failed {
      ContentUnavailableView("Search failed", systemImage: "exclamationmark.triangle")
    } else if !query.isEmpty && model.suggestions.isEmpty {
      ContentUnavailableView.search(text: query)
    } else {
      ForEach(model.suggestions) { suggestion in
        Button {
          Task { await pick(suggestion) }
        } label: {
          VStack(alignment: .leading, spacing: 2) {
            Text(suggestion.title)
            if !suggestion.subtitle.isEmpty {
              Text(suggestion.subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
          }
        }
        .foregroundStyle(.primary)
        .accessibilityIdentifier("place-\(suggestion.title)")
      }
    }
  }

  private func shortcut(_ kind: SavedPlaceKind) -> some View {
    let saved = savedPlaces.places[kind]
    return Button {
      if let saved {
        choose(saved.point)
      } else {
        assigning = kind
      }
    } label: {
      VStack(spacing: 4) {
        Image(systemName: kind == .home ? "house.fill" : "briefcase.fill")
          .font(.title2)
          .foregroundStyle(.white)
          .frame(width: 56, height: 56)
          .background(kind == .home ? Color.cyan : Color.brown, in: Circle())
        Text(kind.label).font(.subheadline)
        Text(saved?.detail ?? "Set")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .frame(maxWidth: 80)
      }
    }
    .buttonStyle(.plain)
    .contextMenu {
      Button("Change \(kind.label)…", systemImage: "pencil") { assigning = kind }
    }
    .accessibilityIdentifier("shortcut-\(kind.label)")
  }

  private func pick(_ suggestion: PlaceSuggestion) async {
    guard let point = await model.resolve(suggestion) else { return }
    guard let kind = assigning else {
      choose(point)
      return
    }
    let detail = suggestion.subtitle.isEmpty ? suggestion.title : suggestion.subtitle
    if let saved = await savedPlaces.set(kind, to: point, detail: detail) {
      assigning = nil
      choose(saved)
    }
  }

  private var resolveFailed: Binding<Bool> {
    Binding(get: { model.resolveFailed }, set: { _ in })
  }

  private func choose(_ place: NamedPoint?) {
    onSelect(place)
    dismiss()
  }
}
