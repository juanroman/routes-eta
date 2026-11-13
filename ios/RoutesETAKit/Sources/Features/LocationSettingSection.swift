import Domain
import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

/// What the commutes list says about location, and what tapping it does. This is the way back in
/// after "Not now" (the system was never asked, so iOS lists nothing in Settings), and the way to
/// Settings after a refusal or after turning Precise Location off.
struct LocationSetting: Equatable {
  enum Action: Equatable {
    case askSystem
    case openSettings
    /// Nothing to do: it's already working.
    case none
  }

  var title: String
  var detail: String?
  var action: Action

  static func `for`(_ authorization: LocationAuthorization) -> LocationSetting {
    switch authorization {
    case .notDetermined:
      LocationSetting(title: "Use my location to pick the commute", detail: nil, action: .askSystem)
    case .authorized:
      LocationSetting(
        title: "Using your location",
        detail: "Home shows the commute that starts where you are.", action: .none)
    case .denied:
      LocationSetting(
        title: "Location is off",
        detail: "Turn it on in Settings to let Home pick the commute that starts where you are.",
        action: .openSettings)
    case .reducedAccuracy:
      LocationSetting(
        title: "Precise location is off",
        detail:
          "Home needs a precise location to tell which commute starts nearby. "
          + "Turn on Precise Location in Settings.",
        action: .openSettings)
    }
  }
}

/// A section for the bottom of the commutes list. Only worth showing with several commutes:
/// with one there is nothing to choose.
struct LocationSettingSection: View {
  let location: any LocationProvider

  @State private var authorization: LocationAuthorization?
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.openURL) private var openURL

  var body: some View {
    Section {
      if let authorization {
        row(LocationSetting.for(authorization))
      }
    } footer: {
      Text("Your location stays on this device. It's only used to pick which commute Home shows.")
    }
    .task { authorization = await location.authorization() }
    // Back from Settings, where the answer may have changed.
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { authorization = await location.authorization() } }
    }
  }

  @ViewBuilder private func row(_ setting: LocationSetting) -> some View {
    switch setting.action {
    case .none:
      content(setting)
    case .askSystem, .openSettings:
      Button {
        perform(setting.action)
      } label: {
        content(setting)
      }
      .accessibilityIdentifier("location-setting-action")
    }
  }

  private func content(_ setting: LocationSetting) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(setting.title)
      if let detail = setting.detail {
        Text(detail).font(.footnote).foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("location-setting")
  }

  private func perform(_ action: LocationSetting.Action) {
    switch action {
    case .askSystem:
      Task { authorization = await location.requestAuthorization() }
    case .openSettings:
      #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
      #endif
    case .none:
      break
    }
  }
}
