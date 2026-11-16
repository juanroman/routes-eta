import Domain
import SwiftUI

/// Google's terms require credit wherever Routes data is shown without a Google map. These
/// numbers are the guide's rules, kept in one place so the logo cannot drift per screen.
enum GoogleMapsAttributionStyle {
  /// Logo height in points: the guide allows 16 to 19.
  static let logoHeight: CGFloat = 18
  /// Logo artwork is 98 x 18, so its width follows from the height; never stretched.
  static let logoAspectRatio: CGFloat = 98.0 / 18.0
  /// Minimum clear space around the logo.
  static let clearTop: CGFloat = 10
  static let clearLeading: CGFloat = 10
  static let clearTrailing: CGFloat = 10
  static let clearBottom: CGFloat = 5
  static let allowedHeights: ClosedRange<CGFloat> = 16...19
  /// Read by VoiceOver and by UI tests; exactly this, never translated.
  static let label = "Google Maps"
  /// Name of the logo image set in the app's asset catalog (gray on light, white on dark).
  static let imageName = "GoogleMapsLogo"
}

/// The official "Google Maps" logo with its required clear space.
struct GoogleMapsAttribution: View {
  private typealias Style = GoogleMapsAttributionStyle

  var body: some View {
    Image(Style.imageName)
      .resizable()
      .aspectRatio(Style.logoAspectRatio, contentMode: .fit)
      .frame(height: Style.logoHeight)
      .padding(
        EdgeInsets(
          top: Style.clearTop, leading: Style.clearLeading, bottom: Style.clearBottom,
          trailing: Style.clearTrailing)
      )
      .accessibilityElement()
      .accessibilityLabel(Text(verbatim: Style.label))
      .accessibilityAddTraits(.isImage)
      .accessibilityIdentifier("google-attribution")
  }
}

/// The Routes numbers and their credit in one bordered container, so Google's data is visibly
/// apart from our own text ("Updated…", "Near Home") and the credit is never separated from it.
struct ETACard: View {
  let commute: Commute
  let report: ETAReport
  /// Dims the numbers (not the credit, which must stay legible) while fresh ones are on the way.
  var isDimmed = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ETAResultsView(commute: commute, report: report)
        .opacity(isDimmed ? 0.4 : 1)
        .animation(.default, value: isDimmed)
        .padding(12)
      GoogleMapsAttribution()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
    .overlay(
      RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
    )
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("eta-card")
  }
}
