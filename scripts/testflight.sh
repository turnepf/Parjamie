#!/bin/bash
# Uploads a new build of Parjamie to TestFlight for internal testing.
#
# Bumps the build number in project.yml, regenerates the Xcode project, archives a
# Release build, and uploads it. Builds reach the Family group automatically once
# Apple finishes processing, with no review. Builds are not locked to internal testing,
# so one can be attached to the App Store version page (that is what makes the icon
# show in App Store Connect). Attaching is harmless; only Add for Review submits. Needs Xcode signed in to the team's
# Apple account (Xcode > Settings > Accounts).
set -euo pipefail
cd "$(dirname "$0")/.."

current=$(sed -n 's/^ *CURRENT_PROJECT_VERSION: "\([0-9]*\)"/\1/p' project.yml)
next=$((current + 1))
sed -i '' "s/CURRENT_PROJECT_VERSION: \"$current\"/CURRENT_PROJECT_VERSION: \"$next\"/" project.yml
xcodegen generate
echo "Building Parjamie build $next"

work=$(mktemp -d)
swift test
xcodebuild archive \
  -project Parjamie.xcodeproj -scheme Parjamie -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$work/Parjamie.xcarchive" -derivedDataPath "$work/DerivedData" \
  -allowProvisioningUpdates
xcodebuild -exportArchive \
  -archivePath "$work/Parjamie.xcarchive" \
  -exportOptionsPlist scripts/ExportOptions.plist \
  -exportPath "$work/export" \
  -allowProvisioningUpdates

echo "Uploaded build $next. Commit project.yml and Parjamie.xcodeproj to record the new build number."
echo "To show the app icon on the App Store Connect home page, attach this build on the iOS 1.0 version page and Save. Never tap Add for Review."
