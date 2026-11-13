import Domain
import SwiftUI

/// One tinted chip per route, in the commute's own order (never sorted: the colour you drew on
/// the map is the colour you read here), with only the quickest marked "Fastest". Shared by the
/// "Show ETAs" sheet and the Home view so they cannot drift apart.
struct ETAResultsView: View {
  let commute: Commute
  let report: ETAReport

  var body: some View {
    VStack(spacing: 12) {
      ForEach(report.results, id: \.name) { result in
        ETAChip(
          result: result,
          color: commute.routes.first { $0.name == result.name }.map { Color(hex: $0.color) }
            ?? .gray,
          isFastest: result.name == report.fastestRouteName && report.results.count > 1)
      }
    }
  }
}

struct ETAChip: View {
  let result: RouteETA
  let color: Color
  let isFastest: Bool

  var body: some View {
    HStack {
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
}
