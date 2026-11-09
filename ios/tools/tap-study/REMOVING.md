# Removing the tap study

The study is designed to be deleted in one go. Everything that is not a tagged hook line
lives in the paths below.

## 1. Delete
- `ios/RoutesETAKit/Sources/Features/TapStudy/` (model, log, observer, sheet)
- `ios/RoutesETAKit/Tests/FeaturesTests/TapStudy/`
- `ios/RoutesETA/RoutesETAUITests/TapStudyUITests.swift`
- `ios/tools/tap-study/` (this directory)

## 2. Remove the five hook lines (each ends in `// TAP-STUDY`)
- `Features/RouteMapEditor.swift`: `.tapStudyScreen(isFullScreen: isFullScreen)`
- `Features/RouteMapView.swift`: `.tapStudyObserver(...)`
- `Features/RouteMapView.swift`: `TapStudyLog.shared.record(.tap, at: point)`
- `Features/RouteEditorView.swift`: `.tapStudyViaChanges(route.via)`
- `Features/CommutesListView.swift`: `TapStudyToolbarItem()`

Then `grep -rn "TAP-STUDY\|TapStudy" ios/` must print nothing (apart from this file's
deletion, and a mention in git history).

## 3. Leftover data on testers' phones
The study keeps `tap-study.json` in the app's Application Support folder and the
`tapStudy.enabled` UserDefaults key. For one release, launch with a one-time cleanup
that deletes the file and the key, then drop the cleanup.

## 4. Check
`ios/check.sh` must pass. `TapStudyRemovalTests` (in the deleted test directory) guards
the hook count while the study exists; its documented count is 5.
