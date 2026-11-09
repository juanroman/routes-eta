#!/usr/bin/env bash
# Archive and upload to App Store Connect (TestFlight).
# Why TestFlight and not Ad Hoc: on the owner's iPhone, Ad Hoc builds kept asking
# for Developer Mode however they were installed; TestFlight builds don't.
# The build number is a timestamp so every upload is unique without touching the repo.
set -euo pipefail
cd "$(dirname "$0")"

TEAM_ID="832TDP3BE8"
BUILD="$(date +%Y%m%d%H%M)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>app-store-connect</string>
<key>destination</key><string>upload</string>
<key>teamID</key><string>$TEAM_ID</string>
<key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST

xcodebuild -project RoutesETA/RoutesETA.xcodeproj -scheme RoutesETA -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$WORK/RoutesETA.xcarchive" \
  CURRENT_PROJECT_VERSION="$BUILD" -allowProvisioningUpdates archive -quiet
xcodebuild -exportArchive -archivePath "$WORK/RoutesETA.xcarchive" -exportPath "$WORK/export" \
  -exportOptionsPlist "$WORK/ExportOptions.plist" -allowProvisioningUpdates
echo "Uploaded build $BUILD"
