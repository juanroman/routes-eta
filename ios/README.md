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

## Google API key (needed once real routes/ETAs are wired in)

The app will call Google's Routes API directly, so it needs a key. The repo is
public, so the key lives in a git-ignored file that Xcode bundles automatically:

1. `cp ios/Secrets.example.plist ios/RoutesETA/RoutesETA/Secrets.plist`
2. Put your key in `GOOGLE_ROUTES_API_KEY`.

`Secrets.plist` is git-ignored, and `ios/check.sh` fails if it is ever tracked. A
clean clone builds without it; the app then shows a message saying how to add it.

Keep the key as limited as you can in Google Cloud Console:
- **API restriction:** allow only the Routes API.
- **Application restriction:** an iOS-apps restriction on bundle ID
  `mx.juanroman.RoutesETA` is available for API keys in general (the app will send
  the `X-Ios-Bundle-Identifier` header), but I couldn't confirm Routes API honors
  it, and Google itself calls bypassing it "straightforward". Treat it as a
  speed bump, not security.
- **Budget alert:** set one on the project. Expected usage is far below the free caps.

The key is inside the app bundle, so anyone with the built app can extract it; that
is the accepted trade-off for a personal app with no server.
