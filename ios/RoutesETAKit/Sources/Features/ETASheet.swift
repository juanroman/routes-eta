import Domain
import SwiftUI

/// "Show ETAs": one colored chip per route, in the commute's own order, with
/// the minutes or "?" when that route failed; the quickest is marked.
struct ETASheet: View {
  let commute: Commute
  @State private var model: ETAModel
  @Environment(\.dismiss) private var dismiss

  init(commute: Commute, service: any ETAService) {
    self.commute = commute
    _model = State(initialValue: ETAModel(service: service, commuteName: commute.name))
  }

  var body: some View {
    NavigationStack {
      content
        .navigationTitle(commute.name)
        .inlineNavigationTitle()
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
          }
        }
    }
    .task { await model.load() }
    .presentationDetents([.medium, .large])
  }

  @ViewBuilder private var content: some View {
    switch model.state {
    case .idle, .loading:
      ProgressView("Checking traffic…").frame(maxWidth: .infinity, maxHeight: .infinity)
    case .failed(let message):
      failure(message)
    case .loaded(let report, let fetchedAt):
      if report.allFailed {
        failure("Couldn't fetch ETAs.", detail: report.results.compactMap(\.error).first)
      } else {
        results(report, fetchedAt: fetchedAt)
      }
    }
  }

  private func results(_ report: ETAReport, fetchedAt: Date) -> some View {
    ScrollView {
      VStack(spacing: 12) {
        ETAResultsView(commute: commute, report: report)
        Text("Updated \(fetchedAt.formatted(date: .omitted, time: .shortened))")
          .font(.footnote).foregroundStyle(.secondary).padding(.top, 4)
        Button("Refresh", systemImage: "arrow.clockwise") { Task { await model.load() } }
          .accessibilityIdentifier("eta-refresh")
      }
      .padding()
    }
    .accessibilityIdentifier("eta-results")
  }

  private func failure(_ message: String, detail: String? = nil) -> some View {
    ContentUnavailableView {
      Label(message, systemImage: "exclamationmark.triangle")
    } description: {
      if let detail { Text(detail) }
    } actions: {
      Button("Try Again") { Task { await model.load() } }
        .accessibilityIdentifier("eta-retry")
    }
  }
}
