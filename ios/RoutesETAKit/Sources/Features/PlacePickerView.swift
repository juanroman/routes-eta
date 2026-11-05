import Domain
import SwiftUI

/// Searchable list of places; used for both origin and destination.
struct PlacePickerView: View {
  let title: String
  let selected: NamedPoint?
  let onSelect: (NamedPoint?) -> Void

  @State private var model: PlacePickerModel
  @State private var query = ""
  @Environment(\.dismiss) private var dismiss

  init(
    title: String, selected: NamedPoint?, service: any PlaceSearchService,
    onSelect: @escaping (NamedPoint?) -> Void
  ) {
    self.title = title
    self.selected = selected
    self.onSelect = onSelect
    _model = State(initialValue: PlacePickerModel(service: service))
  }

  var body: some View {
    NavigationStack {
      List {
        if selected != nil {
          Button("Clear \(title)", role: .destructive) { choose(nil) }
        }
        ForEach(model.results, id: \.label) { place in
          Button {
            choose(place)
          } label: {
            HStack {
              Text(place.label)
              Spacer()
              if place.label == selected?.label {
                Image(systemName: "checkmark").foregroundStyle(.tint)
              }
            }
          }
          .foregroundStyle(.primary)
        }
      }
      .overlay {
        if model.failed {
          ContentUnavailableView("Search failed", systemImage: "exclamationmark.triangle")
        } else if model.results.isEmpty {
          ContentUnavailableView.search(text: query)
        }
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
    }
  }

  private func choose(_ place: NamedPoint?) {
    onSelect(place)
    dismiss()
  }
}
