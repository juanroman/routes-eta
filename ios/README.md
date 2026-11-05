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
