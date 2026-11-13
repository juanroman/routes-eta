import Foundation
import Testing

@testable import Features

struct RouteDistanceFormatTests {
  @Test func mexicoReadsKilometers() {
    #expect(
      RouteDistanceFormat.text(meters: 12_400, locale: Locale(identifier: "es_MX")) == "12.4 km")
  }

  @Test func theUSReadsMiles() {
    #expect(
      RouteDistanceFormat.text(meters: 12_400, locale: Locale(identifier: "en_US")) == "7.7 mi")
  }

  @Test func aWholeNumberHasNoTrailingDecimal() {
    #expect(
      RouteDistanceFormat.text(meters: 10_000, locale: Locale(identifier: "es_MX")) == "10 km")
  }
}
