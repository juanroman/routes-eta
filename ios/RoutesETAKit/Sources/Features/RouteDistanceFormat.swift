import Foundation

/// A route's length as the row shows it: kilometers where the device uses them, miles where
/// it uses those (the app serves both Mexico and the US), to one decimal.
enum RouteDistanceFormat {
  static func text(meters: Int, locale: Locale = .current) -> String {
    Measurement(value: Double(meters), unit: UnitLength.meters)
      .formatted(
        .measurement(
          width: .abbreviated, usage: .road,
          numberFormatStyle: .number.precision(.fractionLength(0...1))
        ).locale(locale))
  }
}
