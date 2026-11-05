import Domain
import SwiftUI

/// Stand-in until the schedule editor (slice 2c).
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
