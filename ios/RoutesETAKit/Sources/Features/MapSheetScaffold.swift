import Domain
import MapKit
import SwiftUI

enum MapSheetMetrics {
  /// The sheet's smallest detent: a title and a couple of rows.
  static let smallHeight: CGFloat = 230
}

/// A full-bleed map with a persistent bottom sheet over it, like Find My: the map is the
/// screen and the sheet holds the details. The map stays usable behind the sheet (up to
/// the medium detent). Screens supply the map content, the sheet content and the points
/// to frame; this owns the camera, the detents and the sheet's comings and goings, so the
/// commute screen and later screens share one behavior.
///
/// Camera: the points are framed in the part of the map the sheet and the bars leave
/// uncovered (`CameraFit`). It refits when the points change (a route was selected, lines
/// finished loading), and when the detent or the screen size changes unless you have moved
/// the map yourself since, so a deliberate pan is not undone by dragging the sheet.
struct MapSheetScaffold<MapBody: MapContent, SheetBody: View>: View {
  /// What to frame; refits whenever this changes.
  let framing: [LatLng]
  /// Whether this screen is the one on top. The sheet belongs to the map, so it must leave
  /// when another screen is pushed over it (it would cover that screen) and come back
  /// when this one returns.
  let isSheetActive: Bool
  let accessibilitySummary: String
  /// A tap on the map, in global coordinates, with the proxy to convert them.
  let onTap: (MapProxy, CGPoint) -> Void
  private let mapContent: MapBody
  private let sheet: SheetBody

  /// Presenting a sheet while a push or pop animation is still running gets dropped.
  private static var presentationDelay: Duration { .milliseconds(250) }

  private struct Layout: Equatable {
    var size: CGSize = .zero
    var topInset: CGFloat = 0
  }

  @State private var position = MapCameraPosition.region(MapRegionFit.fallback)
  @State private var detent = PresentationDetent.height(MapSheetMetrics.smallHeight)
  @State private var layout = Layout()
  @State private var isSheetPresented = false
  /// The rectangle of the last automatic fit, to tell the user's own panning from it.
  @State private var lastFit: MKMapRect?
  @State private var userMoved = false

  init(
    framing: [LatLng], isSheetActive: Bool, accessibilitySummary: String,
    onTap: @escaping (MapProxy, CGPoint) -> Void = { _, _ in },
    @MapContentBuilder map: () -> MapBody, @ViewBuilder sheet: () -> SheetBody
  ) {
    self.framing = framing
    self.isSheetActive = isSheetActive
    self.accessibilitySummary = accessibilitySummary
    self.onTap = onTap
    mapContent = map()
    self.sheet = sheet()
  }

  var body: some View {
    // The reader sits inside the safe area, so it knows the bar heights; the map itself
    // runs under them.
    GeometryReader { proxy in
      let insets = proxy.safeAreaInsets
      let current = Layout(
        size: CGSize(
          width: proxy.size.width + insets.leading + insets.trailing,
          height: proxy.size.height + insets.top + insets.bottom),
        topInset: insets.top)
      MapReader { mapProxy in
        Map(position: $position) { mapContent }
          .onMapCameraChange(frequency: .onEnd) { context in noteCamera(context.rect) }
          .onTapGesture(coordinateSpace: .global) { onTap(mapProxy, $0) }
      }
      .ignoresSafeArea()
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(accessibilitySummary)
      .onChange(of: current, initial: true) { layout = current }
    }
    .onChange(of: layout) { refit(force: false) }
    .onChange(of: framing, initial: true) { refit(force: true) }
    .onChange(of: detent) { refit(force: false) }
    .task(id: isSheetActive) {
      guard isSheetActive else {
        isSheetPresented = false
        return
      }
      try? await Task.sleep(for: Self.presentationDelay)
      if !Task.isCancelled { isSheetPresented = true }
    }
    .sheet(isPresented: Binding(get: { isSheetPresented }, set: { _ in })) {
      sheet.persistentSheet(selection: $detent)
    }
  }

  // MARK: Camera

  /// How much of the map the sheet covers at the current detent. The large detent covers
  /// nearly all of it, so it is framed as if medium.
  private var bottomInset: CGFloat {
    detent == .height(MapSheetMetrics.smallHeight)
      ? MapSheetMetrics.smallHeight : layout.size.height / 2
  }

  private func refit(force: Bool) {
    guard
      let rect = CameraFit.rect(
        fitting: framing, mapSize: layout.size, topInset: layout.topInset,
        bottomInset: bottomInset)
    else { return }
    if !force && (userMoved || detent == .large) { return }
    lastFit = rect
    userMoved = false
    withAnimation(.easeInOut) { position = .rect(rect) }
  }

  /// A camera that settled somewhere other than where we put it was moved by the user.
  private func noteCamera(_ settled: MKMapRect) {
    guard let lastFit else { return }
    let tolerance = lastFit.width * 0.02
    let moved =
      abs(settled.minX - lastFit.minX) > tolerance || abs(settled.minY - lastFit.minY) > tolerance
      || abs(settled.width - lastFit.width) > tolerance
    if moved { userMoved = true }
  }
}

extension View {
  /// Detents and "keep the map usable behind it" for the persistent sheet. iOS only, so the
  /// package still builds on the macOS test host.
  fileprivate func persistentSheet(selection: Binding<PresentationDetent>) -> some View {
    #if os(iOS)
      presentationDetents(
        [.height(MapSheetMetrics.smallHeight), .medium, .large], selection: selection
      )
      .presentationBackgroundInteraction(.enabled(upThrough: .medium))
      .presentationDragIndicator(.visible)
      .interactiveDismissDisabled()
    #else
      self
    #endif
  }
}
