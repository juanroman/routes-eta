import Domain

/// Seed data for previews and the in-memory services. Kept equal to
/// `fixtures/sample-config.json` by a contract test, so it can't drift from
/// what the API/web actually exchange.
public enum SampleData {
  public static let work = NamedPoint(label: "Work", lat: 19.4284, lng: -99.1677)
  public static let home = NamedPoint(label: "Home", lat: 19.5095, lng: -99.2383)

  public static let config = Config(
    timezone: "America/Mexico_City",
    commutes: [
      Commute(
        name: "Work to Home",
        origin: work,
        destination: home,
        routes: [
          RouteDef(
            name: "City", color: "#2563eb", via: [LatLng(lat: 19.455, lng: -99.205)]),
          RouteDef(name: "Mordor", color: "#dc2626"),
        ],
        schedules: [ScheduleRule(weekdays: [.mon, .tue, .wed, .thu, .fri], time: "18:30")]
      ),
      Commute(
        name: "Home to Work",
        origin: home,
        destination: work,
        routes: [
          RouteDef(
            name: "City", color: "#2563eb", via: [LatLng(lat: 19.455, lng: -99.205)])
        ],
        schedules: [
          ScheduleRule(weekdays: [.mon], time: "06:30"),
          ScheduleRule(weekdays: [.tue, .wed, .thu, .fri], time: "07:30"),
        ]
      ),
    ]
  )
}
