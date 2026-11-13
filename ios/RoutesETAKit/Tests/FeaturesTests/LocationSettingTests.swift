import Domain
import Testing

@testable import Features

struct LocationSettingTests {
  @Test func anUndecidedUserCanStillBeAsked() {
    let setting = LocationSetting.for(.notDetermined)
    #expect(setting.action == .askSystem)
    #expect(setting.title == "Use my location to pick the commute")
  }

  @Test func whenItWorksThereIsNothingToDo() {
    let setting = LocationSetting.for(.authorized)
    #expect(setting.action == .none)
    #expect(setting.title == "Using your location")
  }

  @Test func aRefusalSendsTheUserToSettings() {
    let setting = LocationSetting.for(.denied)
    #expect(setting.action == .openSettings)
    #expect(setting.title == "Location is off")
  }

  @Test func approximateLocationSaysWhatToTurnOn() {
    let setting = LocationSetting.for(.reducedAccuracy)
    #expect(setting.action == .openSettings)
    #expect(setting.detail?.contains("Precise Location") == true)
  }

  @Test func everyStateExplainsItself() {
    for state in [LocationAuthorization.notDetermined, .authorized, .denied, .reducedAccuracy] {
      #expect(!LocationSetting.for(state).title.isEmpty)
    }
  }
}
