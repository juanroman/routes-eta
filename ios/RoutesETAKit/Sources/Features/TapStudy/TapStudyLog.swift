import Foundation
import Observation

/// Keeps the study's events on this device (a bounded ring buffer saved to one JSON
/// file) and builds the export. Off unless the tester switches it on; while off,
/// `record` does nothing and the touch observer is not even attached.
@MainActor
@Observable
final class TapStudyLog {
  static let enabledKey = "tapStudy.enabled"
  static let capacity = 500
  /// Mirrors `RouteMapView.hitRadius`; written into the export so the analysis knows
  /// what tolerance the app was using.
  static let hitRadiusPoints = 30.0
  static let shared = makeShared()

  private(set) var events: [TapEvent]
  /// The map as it was when the last touch began; taps and flags borrow it.
  var context = TapStudyContext()
  var isEnabled: Bool {
    didSet { defaults.set(isEnabled, forKey: Self.enabledKey) }
  }

  @ObservationIgnored private let session = UUID().uuidString
  @ObservationIgnored private let url: URL
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let capacity: Int
  @ObservationIgnored private let clock: () -> Date
  @ObservationIgnored private let startedAt: Date
  @ObservationIgnored private var saveTask: Task<Void, Never>?

  init(
    url: URL, defaults: UserDefaults = .standard, capacity: Int = TapStudyLog.capacity,
    clock: @escaping () -> Date = { Date() }
  ) {
    self.url = url
    self.defaults = defaults
    self.capacity = capacity
    self.clock = clock
    startedAt = clock()
    isEnabled = defaults.bool(forKey: Self.enabledKey)
    events = Self.savedEvents(at: url).suffix(capacity)
  }

  func record(
    _ kind: TapEvent.Kind, at point: CGPoint? = nil, touch: TapTouch? = nil,
    context override: TapStudyContext? = nil
  ) {
    guard isEnabled else { return }
    let shown = override ?? context
    events.append(
      TapEvent(
        time: Self.rounded(clock().timeIntervalSince(startedAt), places: 3), session: session,
        kind: kind, screen: shown.screen,
        metresPerPoint: shown.metresPerPoint.map { Self.rounded($0, places: 2) },
        vertices: shown.vertices, viaCount: shown.viaCount,
        x: point.map { Self.rounded($0.x, places: 1) },
        y: point.map { Self.rounded($0.y, places: 1) },
        distToLine: touch?.distToLine.map { Self.rounded($0, places: 1) },
        distToHandle: touch?.distToHandle.map { Self.rounded($0, places: 1) },
        travel: touch?.travel.map { Self.rounded($0, places: 1) },
        duration: touch?.duration.map { Self.rounded($0, places: 3) },
        cancelled: touch?.cancelled == true ? true : nil))
    if events.count > capacity { events.removeFirst(events.count - capacity) }
    scheduleSave()
  }

  /// Records an edit to the via list, classified by what changed.
  func recordViaChange<Element: Equatable>(from old: [Element], to new: [Element]) {
    guard let kind = TapStudyViaDiff.kind(from: old, to: new) else { return }
    var shown = context
    shown.viaCount = new.count
    record(kind, context: shown)
  }

  func clear() {
    saveTask?.cancel()
    events = []
    try? FileManager.default.removeItem(at: url)
  }

  func exportData() -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return (try? encoder.encode(makeExport())) ?? Data()
  }

  /// Writes now instead of waiting for the debounce.
  func flush() {
    saveTask?.cancel()
    try? FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? exportData().write(to: url, options: .atomic)
  }

  // MARK: Private

  private func makeExport() -> TapStudyExport {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "?"
    let build = info?["CFBundleVersion"] as? String ?? "?"
    return TapStudyExport(
      app: "\(version) (\(build))", device: Self.deviceModel,
      os: ProcessInfo.processInfo.operatingSystemVersionString, hitRadiusPt: Self.hitRadiusPoints,
      events: events)
  }

  private func scheduleSave() {
    saveTask?.cancel()
    saveTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(2))
      guard !Task.isCancelled else { return }
      self?.flush()
    }
  }

  private static func savedEvents(at url: URL) -> [TapEvent] {
    guard let data = try? Data(contentsOf: url),
      let saved = try? JSONDecoder().decode(TapStudyExport.self, from: data)
    else { return [] }
    return saved.events
  }

  private static func rounded(_ value: Double, places: Int) -> Double {
    let scale = pow(10.0, Double(places))
    return (value * scale).rounded() / scale
  }

  private static var deviceModel: String {
    if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
      return simulated
    }
    var system = utsname()
    uname(&system)
    let name = withUnsafeBytes(of: system.machine) { Data($0.prefix { $0 != 0 }) }
    return String(bytes: name, encoding: .utf8) ?? "unknown"
  }

  /// The app's log. UI tests (`-mock-services`) get a throwaway file and settings so a
  /// run never sees an earlier one; `-tap-study-on` switches recording on for them.
  private static func makeShared() -> TapStudyLog {
    let arguments = CommandLine.arguments
    guard arguments.contains("-mock-services") else {
      let folder =
        (try? FileManager.default.url(
          for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
          create: true)) ?? FileManager.default.temporaryDirectory
      return TapStudyLog(url: folder.appending(path: "tap-study.json"))
    }
    let defaults = UserDefaults(suiteName: "tap-study.test.\(UUID().uuidString)") ?? .standard
    let log = TapStudyLog(
      url: FileManager.default.temporaryDirectory.appending(path: "tap-study-\(UUID()).json"),
      defaults: defaults)
    log.isEnabled = arguments.contains("-tap-study-on")
    return log
  }
}
