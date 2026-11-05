extension Weekday {
  public var shortName: String {
    switch self {
    case .mon: "Mon"
    case .tue: "Tue"
    case .wed: "Wed"
    case .thu: "Thu"
    case .fri: "Fri"
    case .sat: "Sat"
    case .sun: "Sun"
    }
  }
}

extension ScheduleRule {
  /// "Tue–Fri · 07:30". Runs of three or more consecutive days collapse to a range.
  public var summary: String {
    "\(Self.describe(weekdays)) · \(time)"
  }

  static func describe(_ days: [Weekday]) -> String {
    let order = Weekday.allCases
    let indexes = Set(days.compactMap { order.firstIndex(of: $0) }).sorted()
    var parts: [String] = []
    var run: [Int] = []

    func flush() {
      if run.count >= 3, let first = run.first, let last = run.last {
        parts.append("\(order[first].shortName)–\(order[last].shortName)")
      } else {
        parts += run.map { order[$0].shortName }
      }
      run = []
    }

    for index in indexes {
      if let last = run.last, index != last + 1 { flush() }
      run.append(index)
    }
    flush()
    return parts.joined(separator: ", ")
  }
}
