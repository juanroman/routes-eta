import Domain
import SwiftUI

/// Stand-ins so navigation can be built and tested now; replaced in Phase 2.
struct RouteEditorPlaceholderView: View {
  let store: ConfigStore
  let commuteID: CommuteEntry.ID
  let routeName: String

  var body: some View {
    ContentUnavailableView(
      routeName, systemImage: "map",
      description: Text("The route editor arrives in Phase 2.")
    )
    .navigationTitle(routeName)
    .inlineNavigationTitle()
  }
}

struct ScheduleEditorPlaceholderView: View {
  let store: ConfigStore
  let commuteID: CommuteEntry.ID

  var body: some View {
    ContentUnavailableView(
      "Schedule", systemImage: "calendar",
      description: Text("The schedule editor arrives in Phase 2.")
    )
    .navigationTitle("Schedule")
    .inlineNavigationTitle()
  }
}
