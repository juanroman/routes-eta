# iOS app (`ios/`)

Native SwiftUI client for the commute/routes editor and the "show ETAs"
button. Built mock-first: UI against in-memory services, real networking to
`api/` later.

- `RoutesETA/` — thin Xcode app target (iOS 27.2+, Swift 6, strict concurrency
  `complete`, warnings as errors).
- `RoutesETAKit/` — local Swift package: `Domain` (models, validation, service
  protocols; platform-neutral so a watchOS target can reuse it), `Mocks`
  (in-memory services), `Features` (iOS-only SwiftUI).
- Tests use Swift Testing. `ios/check.sh` runs swift-format (strict), SwiftLint
  (strict), package tests and the app tests on a simulator.

Tooling: `xcrun swift-format` ships with Xcode; install SwiftLint with
`brew install swiftlint`.

## Languages (English, Spanish Mexico)

Strings live in two String Catalogs in the **app target** (`RoutesETA/RoutesETA/`):
`Localizable.xcstrings` (the UI) and `InfoPlist.xcstrings` (the location permission prompt).
The keys are the English text; `es-MX` is the only translation.

- **Why the app and not the package:** SwiftUI looks `Text("…")`, `Button("…")` and friends up in
  the main bundle, so one catalog covers `RoutesETAKit` without a `bundle:` on every call.
- **Xcode does not extract package strings into this catalog.** When you add or change a
  user-facing string, add or edit its key in `Localizable.xcstrings` by hand, with the exact
  English text; an interpolation is `%@` (String) or `%lld` (Int), e.g. `Near %@`.
  `RoutesETATests/LocalizationCatalogTests` fails if a key has no es-MX translation or its
  placeholders differ from the English.
- **`Text(someString)` is not localized**, only literals and `LocalizedStringKey`. For text built
  in code use `String(localized: "…")`, or pass a `LocalizedStringKey`.
- **Plurals** are one key per wording ("1 route" / "%lld routes"), not catalog plural variations,
  so the English key is also the fallback in package tests and previews, where no catalog is loaded.
- Accessibility identifiers stay English (UI tests find views by them); only visible text changes.
- **Try it:** Edit Scheme → Run → Options → App Language → Spanish (Mexico), or launch with
  `-AppleLanguages "(es-MX)" -AppleLocale es_MX`. `LocalizationUITests` does the latter.

## Google API key (needed for route lines and ETAs)

The app calls Google's Routes API directly (no server), so it needs a key. The repo is
public, so the key lives in a git-ignored file that Xcode bundles automatically:

1. `cp ios/Secrets.example.plist ios/RoutesETA/RoutesETA/Secrets.plist`
2. Put your key in `GOOGLE_ROUTES_API_KEY`.

`Secrets.plist` is git-ignored, and `ios/check.sh` fails if it is ever tracked. A
clean clone builds without it; the app then shows a message saying how to add it.

Keep the key as limited as you can in Google Cloud Console:
- **API restriction:** allow only the Routes API.
- **Application restriction:** an iOS-apps restriction on bundle ID
  `mx.juanroman.RoutesETA` is available for API keys in general (the app sends
  the `X-Ios-Bundle-Identifier` header), but I couldn't confirm Routes API honors
  it, and Google itself calls bypassing it "straightforward". Treat it as a
  speed bump, not security.
- **Budget alert:** set one on the project. Expected usage is far below the free caps.

The key is inside the app bundle, so anyone with the built app can extract it; that
is the accepted trade-off for a personal app with no server.

### Checking the key works

The normal test suite never touches Google. To run two real requests (one route
preview, one ETA) against your key:

    cd ios/RoutesETAKit
    GOOGLE_ROUTES_API_KEY="$(plutil -extract GOOGLE_ROUTES_API_KEY raw ../RoutesETA/RoutesETA/Secrets.plist)" \
      swift test --filter GoogleLiveSmokeTests

### How the app talks to Google

`Platform/GoogleRoutesClient` is a Swift port of `api/app/google_routes_client.py`
(same endpoint, field masks, `via` waypoints that pass through without stopping,
and `TRAFFIC_AWARE` for ETAs; minutes rounded half-to-even like the Pi's checker),
so the app and the Pi ask Google the same question. `api/` and `web/` are not used
by the app and are not kept in sync with it.
