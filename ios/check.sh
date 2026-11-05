#!/usr/bin/env bash
# "Is the iOS project green?" — mirrors api/check.sh and `npm run check`.
# Order: format -> lint -> package tests -> app build+tests on a simulator.
set -euo pipefail
cd "$(dirname "$0")"

SIM_NAME="${SIM_NAME:-iPhone 18 Pro}"
SIM_OS="${SIM_OS:-27.2}" # several runtimes are installed; the name alone is ambiguous
SWIFT_DIRS=(RoutesETAKit/Sources RoutesETAKit/Tests RoutesETA/RoutesETA RoutesETA/RoutesETATests RoutesETA/RoutesETAUITests)

echo "--- swift-format (lint, strict) ---"
xcrun swift-format lint --strict --recursive "${SWIFT_DIRS[@]}"

echo "--- swiftlint (strict) ---"
if ! command -v swiftlint >/dev/null; then
  echo "swiftlint not installed (brew install swiftlint)" >&2
  exit 1
fi
swiftlint lint --strict --quiet

echo "--- package tests (warnings are errors) ---"
(cd RoutesETAKit && swift test)

echo "--- app build + tests (xcodebuild) ---"
xcodebuild test -project RoutesETA/RoutesETA.xcodeproj -scheme RoutesETA \
  -destination "platform=iOS Simulator,name=${SIM_NAME},OS=${SIM_OS}" -quiet
echo "iOS checks passed."
