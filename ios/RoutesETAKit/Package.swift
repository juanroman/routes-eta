// swift-tools-version: 6.4
import PackageDescription

// Domain and Mocks are deliberately platform-neutral (no UIKit/MapKit) so a
// future watchOS target can link them unchanged. Features is iOS-only.
let strict: [SwiftSetting] = [.treatAllWarnings(as: .error)]

let package = Package(
  name: "RoutesETAKit",
  platforms: [.iOS("27.2"), .watchOS(.v27), .macOS(.v27)],
  products: [
    .library(name: "Domain", targets: ["Domain"]),
    .library(name: "Mocks", targets: ["Mocks"]),
    .library(name: "Features", targets: ["Features"]),
  ],
  targets: [
    .target(name: "Domain", swiftSettings: strict),
    .target(name: "Mocks", dependencies: ["Domain"], swiftSettings: strict),
    .target(name: "Features", dependencies: ["Domain", "Mocks"], swiftSettings: strict),
    .testTarget(name: "DomainTests", dependencies: ["Domain"], swiftSettings: strict),
    .testTarget(name: "MocksTests", dependencies: ["Mocks", "Domain"], swiftSettings: strict),
    .testTarget(
      name: "FeaturesTests", dependencies: ["Features", "Domain", "Mocks"], swiftSettings: strict),
  ],
  swiftLanguageModes: [.v6]
)
