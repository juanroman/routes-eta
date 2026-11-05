import Domain
import SwiftUI

struct CommuteDetailView: View {
  let store: ConfigStore
  let commuteID: CommuteEntry.ID

  var body: some View {
    if let entry = store.entry(id: commuteID) {
      content(for: entry.commute)
    } else {
      ContentUnavailableView("Commute not found", systemImage: "questionmark.circle")
    }
  }

  private func content(for commute: Commute) -> some View {
    List {
      Section("Trip") {
        LabeledContent("From", value: commute.origin?.label ?? "Not set")
        LabeledContent("To", value: commute.destination?.label ?? "Not set")
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
    .navigationTitle(commute.name)
    .inlineNavigationTitle()
  }
}
