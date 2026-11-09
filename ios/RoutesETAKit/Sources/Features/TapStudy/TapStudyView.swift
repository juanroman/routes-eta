import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// The commutes-list toolbar entry that opens the study sheet.
struct TapStudyToolbarItem: ToolbarContent {
  var body: some ToolbarContent {
    ToolbarItem(placement: .navigation) { TapStudyButton() }
  }
}

struct TapStudyButton: View {
  @State private var isPresented = false

  var body: some View {
    Button("Tap study", systemImage: "hand.tap") { isPresented = true }
      .accessibilityIdentifier("tap-study-menu")
      .sheet(isPresented: $isPresented) { TapStudyView() }
  }
}

/// The export as a shareable `.json` file.
struct TapStudyFile: Transferable {
  let data: Data

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .json) { $0.data }
      .suggestedFileName("tap-study.json")
  }
}

struct TapStudyView: View {
  @Bindable private var log = TapStudyLog.shared
  @Environment(\.dismiss) private var dismiss
  @State private var isConfirmingClear = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Toggle("Record taps on the route map", isOn: $log.isEnabled)
            .accessibilityIdentifier("tap-study-toggle")
        } footer: {
          Text(
            """
            Records where your finger touches the route map (its distance to the route line \
            in screen points, the zoom, how far and how long the finger moved) and when via \
            points are added, moved or removed. It never records locations, place names or \
            route names. Everything stays on this phone until you share it.
            """)
        }
        Section("Recorded on this phone") {
          HStack {
            Text("Events")
            Spacer()
            Text("\(log.events.count)")
              .foregroundStyle(.secondary)
              .accessibilityIdentifier("tap-study-count")
          }
          ShareLink(
            item: TapStudyFile(data: log.exportData()), preview: SharePreview("Tap study data")
          ) {
            Label("Share data…", systemImage: "square.and.arrow.up")
          }
          .disabled(log.events.isEmpty)
          Button("Clear data", role: .destructive) { isConfirmingClear = true }
            .disabled(log.events.isEmpty)
        }
      }
      .navigationTitle("Tap study")
      .inlineNavigationTitle()
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
      }
      .confirmationDialog("Clear all recorded taps?", isPresented: $isConfirmingClear) {
        Button("Clear Data", role: .destructive) { log.clear() }
        Button("Cancel", role: .cancel) {}
      }
    }
  }
}
