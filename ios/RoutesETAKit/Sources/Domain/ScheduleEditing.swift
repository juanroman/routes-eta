extension ScheduleRule {
  public var hour: Int? { Self.parse(time)?.hour }
  public var minute: Int? { Self.parse(time)?.minute }

  /// Sets `time` to a zero-padded `HH:MM`.
  public mutating func setTime(hour: Int, minute: Int) {
    time = Self.pad(hour) + ":" + Self.pad(minute)
  }

  private static func pad(_ value: Int) -> String {
    value < 10 ? "0\(value)" : "\(value)"
  }

  private static func parse(_ time: String) -> (hour: Int, minute: Int)? {
    let parts = time.split(separator: ":")
    guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else {
      return nil
    }
    return (hour, minute)
  }
}

extension Commute {
  /// Weekdays claimed by every schedule rule except the one at `index`.
  public func weekdaysUsed(excludingRuleAt index: Int) -> Set<Weekday> {
    var used = Set<Weekday>()
    for (offset, rule) in schedules.enumerated() where offset != index {
      used.formUnion(rule.weekdays)
    }
    return used
  }

  public var unscheduledWeekdays: [Weekday] {
    let used = weekdaysUsed(excludingRuleAt: -1)
    return Weekday.allCases.filter { !used.contains($0) }
  }

  /// Adds a rule on the still-free weekdays (Mon–Fri if any are free, else the
  /// first free day) at the default time. Nil when every weekday is taken.
  @discardableResult
  public mutating func addScheduleRule() -> Int? {
    let free = unscheduledWeekdays
    guard let first = free.first else { return nil }
    let workdays = free.filter { ![.sat, .sun].contains($0) }
    schedules.append(ScheduleRule(weekdays: workdays.isEmpty ? [first] : workdays))
    return schedules.count - 1
  }

  /// A weekday chip may be switched on only if no other rule has it, and off
  /// only if it isn't the rule's last day (a rule needs at least one).
  public func canToggle(_ day: Weekday, inRuleAt index: Int) -> Bool {
    guard schedules.indices.contains(index) else { return false }
    if schedules[index].weekdays.contains(day) { return schedules[index].weekdays.count > 1 }
    return !weekdaysUsed(excludingRuleAt: index).contains(day)
  }

  /// Toggles a weekday if allowed (see `canToggle`); keeps days in week order.
  @discardableResult
  public mutating func toggle(_ day: Weekday, inRuleAt index: Int) -> Bool {
    guard canToggle(day, inRuleAt: index) else { return false }
    var days = Set(schedules[index].weekdays)
    if days.contains(day) { days.remove(day) } else { days.insert(day) }
    schedules[index].weekdays = Weekday.allCases.filter(days.contains)
    return true
  }
}
