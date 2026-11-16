import CoreGraphics
import Testing

@testable import Features

/// Google's attribution guide, as numbers: if someone "tidies" the logo, these fail.
struct GoogleMapsAttributionStyleTests {
  private typealias Style = GoogleMapsAttributionStyle

  @Test func logoHeightIsWithinTheAllowedRange() {
    #expect(Style.allowedHeights.contains(Style.logoHeight))
  }

  @Test func logoKeepsTheArtworksAspectRatio() {
    // The supplied artwork is 98 x 18 points.
    #expect(abs(Style.logoAspectRatio - 98.0 / 18.0) < 0.001)
  }

  @Test func clearSpaceMeetsTheMinimums() {
    #expect(Style.clearTop >= 10)
    #expect(Style.clearLeading >= 10)
    #expect(Style.clearTrailing >= 10)
    #expect(Style.clearBottom >= 5)
  }

  @Test func labelIsExactlyGoogleMaps() {
    #expect(Style.label == "Google Maps")
  }
}
