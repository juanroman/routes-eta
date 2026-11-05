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
        failure("Couldn't fetch ETAs.")
      } else {
        results(report, fetchedAt: fetchedAt)
      }
    }
  }

  private func results(_ report: ETAReport, fetchedAt: Date) -> some View {
    ScrollView {
      VStack(spacing: 12) {
        ForEach(report.results, id: \.name) { result in
          chip(
            result, isFastest: result.name == report.fastestRouteName && report.results.count > 1)
        }
        Text("Updated \(fetchedAt.formatted(date: .omitted, time: .shortened))")
          .font(.footnote).foregroundStyle(.secondary).padding(.top, 4)
        Button("Refresh", systemImage: "arrow.clockwise") { Task { await model.load() } }
          .accessibilityIdentifier("eta-refresh")
      }
      .padding()
    }
    .accessibilityIdentifier("eta-results")
  }

  private func chip(_ result: RouteETA, isFastest: Bool) -> some View {
    let color =
      commute.routes.first { $0.name == result.name }.map { Color(hex: $0.color) } ?? .gray
    return HStack {
      Circle().fill(color).frame(width: 14, height: 14)
      VStack(alignment: .leading, spacing: 2) {
        Text(result.name).font(.headline)
        if isFastest { Text("Fastest").font(.caption).foregroundStyle(.green) }
        if let error = result.error { Text(error).font(.caption).foregroundStyle(.secondary) }
      }
      Spacer()
      Text(result.minutes.map { "\($0) min" } ?? "?").font(.title2.bold())
    }
    .padding()
    .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("eta-\(result.name)")
  }

  private func failure(_ message: String) -> some View {
    ContentUnavailableView {
      Label(message, systemImage: "exclamationmark.triangle")
    } actions: {
      Button("Try Again") { Task { await model.load() } }
        .accessibilityIdentifier("eta-retry")
    }
  }
}
