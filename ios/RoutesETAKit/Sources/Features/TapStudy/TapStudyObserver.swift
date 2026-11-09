import Domain
import MapKit
import SwiftUI

extension EnvironmentValues {
  /// Whether the map being touched is the inline one or the full-screen one.
  @Entry var tapStudyScreen: TapEvent.Screen = .inline
}

extension View {
  /// Tells the study which map this is and adds the "Tap didn't work" button.
  func tapStudyScreen(isFullScreen: Bool) -> some View {
    environment(\.tapStudyScreen, isFullScreen ? .full : .inline)
      .overlay(alignment: .topLeading) { TapStudyFlagButton() }
  }

  /// Watches raw touches on the map. Apply it inside a `MapReader`.
  func tapStudyObserver(polyline: [LatLng], via: [LatLng], proxy: MapProxy) -> some View {
    modifier(TapStudyObserver(polyline: polyline, via: via, proxy: proxy))
  }

  /// Notes when the via list gains, loses or moves a point.
  func tapStudyViaChanges(_ via: [LatLng]) -> some View {
    onChange(of: via) { old, new in TapStudyLog.shared.recordViaChange(from: old, to: new) }
  }
}

/// A pure observer: records where each touch began (as distances to the route line
/// and to the nearest via handle, in points) and how it ended, without taking part
/// in any gesture. Comparing these with the map's own `tap` events shows touches that
/// began on the line but never became a tap. Only attached while the study is on.
struct TapStudyObserver: ViewModifier {
  let polyline: [LatLng]
  let via: [LatLng]
  let proxy: MapProxy
  @Environment(\.tapStudyScreen) private var screen
  /// A reference, so tracking a touch never re-renders the map.
  @State private var tracker = TapStudyTouchTracker()

  func body(content: Content) -> some View {
    content.simultaneousGesture(gesture, isEnabled: TapStudyLog.shared.isEnabled)
  }

  private var gesture: some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .global)
      .onChanged { value in
        if let current = tracker.current {
          if current.start == value.startLocation { return }
          // A new touch began and the old one never ended.
          finish(current, travel: nil, duration: nil, cancelled: true)
        }
        begin(at: value.startLocation, time: value.time)
      }
      .onEnded { value in
        guard let current = tracker.current else { return }
        finish(
          current, travel: hypot(value.translation.width, value.translation.height),
          duration: value.time.timeIntervalSince(current.startTime), cancelled: false)
      }
  }

  private func begin(at start: CGPoint, time: Date) {
    let line = polyline.compactMap { proxy.convert($0.coordinate, to: .global) }
    let handles = via.compactMap { proxy.convert($0.coordinate, to: .global) }
    let context = TapStudyContext(
      screen: screen, metresPerPoint: metresPerPoint(), vertices: polyline.count,
      viaCount: via.count)
    TapStudyLog.shared.context = context
    tracker.current = TapStudyTouchTracker.Touch(
      start: start, startTime: time, context: context,
      distToLine: line.isEmpty ? nil : ScreenGeometry.distance(from: start, toPolyline: line),
      distToHandle: handles.map { hypot(start.x - $0.x, start.y - $0.y) }.min())
  }

  private func finish(
    _ touch: TapStudyTouchTracker.Touch, travel: Double?, duration: Double?, cancelled: Bool
  ) {
    tracker.current = nil
    TapStudyLog.shared.record(
      .touch, at: touch.start,
      touch: TapTouch(
        distToLine: touch.distToLine, distToHandle: touch.distToHandle, travel: travel,
        duration: duration, cancelled: cancelled),
      context: touch.context)
  }

  /// Ground metres per screen point, from the two ends of the route line.
  private func metresPerPoint() -> Double? {
    guard let first = polyline.first, let last = polyline.last,
      let from = proxy.convert(first.coordinate, to: .global),
      let to = proxy.convert(last.coordinate, to: .global)
    else { return nil }
    let screenDistance = hypot(from.x - to.x, from.y - to.y)
    guard screenDistance > 1 else { return nil }
    let ground = CLLocation(latitude: first.lat, longitude: first.lng)
      .distance(from: CLLocation(latitude: last.lat, longitude: last.lng))
    return ground / screenDistance
  }
}

/// The touch in progress, kept outside the view's state so it never triggers a redraw.
@MainActor
final class TapStudyTouchTracker {
  struct Touch {
    var start: CGPoint
    var startTime: Date
    var context: TapStudyContext
    var distToLine: Double?
    var distToHandle: Double?
  }
  var current: Touch?
}

/// Lets the tester label a miss: the touches just before this are the ones to inspect.
struct TapStudyFlagButton: View {
  @State private var notedCount = 0
  @State private var showsNoted = false

  var body: some View {
    if TapStudyLog.shared.isEnabled {
      HStack(spacing: 8) {
        Button {
          TapStudyLog.shared.record(.flag)
          notedCount += 1
          showsNoted = true
          Task {
            try? await Task.sleep(for: .seconds(1.5))
            showsNoted = false
          }
        } label: {
          Label("Tap didn't work", systemImage: "hand.tap")
            .labelStyle(.iconOnly)
            .font(.title3)
            .frame(width: 44, height: 44)
            .background(.regularMaterial, in: Circle())
        }
        .accessibilityIdentifier("tap-study-flag")
        if showsNoted {
          Text("Noted").font(.footnote.bold()).padding(8).background(
            .regularMaterial, in: Capsule())
        }
      }
      .padding(8)
      .sensoryFeedback(.success, trigger: notedCount)
    }
  }
}
