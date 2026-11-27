#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
xcodebuild -version
sdk_version=$(xcrun --sdk iphoneos --show-sdk-version)
if (( ${sdk_version%%.*} < 26 )); then
  echo "Select Xcode 26 or newer to build the on-device coach." >&2
  exit 1
fi

# A toolchain with only the fallback branch must not pass as an AI-capable build.
xcrun swiftc -typecheck -sdk "$(xcrun --sdk iphoneos --show-sdk-path)" -target arm64-apple-ios17.0 - <<'SWIFT'
#if !compiler(>=6.2)
#error("The on-device coach requires Swift 6.2 or newer.")
#endif
import FoundationModels
SWIFT

project_args=(-project BodyNote.xcodeproj -scheme BodyNote)
xcodebuild "${project_args[@]}" -configuration Release \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build

device_family=${WORKOUT_SIM_FAMILY:-iPhone}
case "$device_family" in
  iPhone|iPad) ;;
  *) echo "Expected iPhone or iPad, got $device_family" >&2; exit 1 ;;
esac
simulator=$(xcrun simctl list devices available --json | python3 -c '
import json, re, sys
candidates = []
family = sys.argv[1]
for runtime, devices in json.load(sys.stdin)["devices"].items():
    match = re.fullmatch(r"com\.apple\.CoreSimulator\.SimRuntime\.iOS-(\d+(?:-\d+)*)", runtime)
    if match:
        version = tuple(map(int, match[1].split("-")))
        for device in devices:
            if version[0] >= 26 and device["name"].startswith(family) and device["isAvailable"]:
                candidates.append((version, device["state"] == "Booted", device["udid"]))
if not candidates:
    sys.exit(f"Install an iOS 26 or newer {family} simulator in Xcode Settings > Components.")
print(max(candidates)[2])
' "$device_family")

# Wait for SpringBoard and the simulator services before XCTest launches the app.
xcrun simctl bootstatus "$simulator" -b
fixture_dir=$(mktemp -d)
cp BodyNote/Assets.xcassets/TrackBadge.imageset/art.png "$fixture_dir/WorkoutLogAttachmentFixture.png"
xcrun simctl addmedia "$simulator" "$fixture_dir/WorkoutLogAttachmentFixture.png"

result_path=${WORKOUT_UI_RESULT_PATH:-"$(mktemp -d)/WorkoutLog.xcresult"}
test_args=(-configuration Debug -destination "platform=iOS Simulator,id=$simulator,arch=$(uname -m)"
  -parallel-testing-enabled NO -resultBundlePath "$result_path")
ui_tests=BodyNoteUITests/WorkoutJournalUITests
if [[ "$device_family" == iPad ]]; then
  test_args+=("-only-testing:$ui_tests/testPhotoPickerAttachesAnImageToJournal"
              "-only-testing:$ui_tests/testIPadDrawingSurvivesRelaunchAndAttachesToJournal")
else
  test_args+=("-skip-testing:$ui_tests/testIPadDrawingSurvivesRelaunchAndAttachesToJournal")
fi
archive_path=${WORKOUT_SIMULATOR_ZIP_PATH:-}
if [[ -n "$archive_path" ]]; then
  simulator_build=$(mktemp -d)
  test_args+=(-derivedDataPath "$simulator_build")
fi
xcodebuild "${project_args[@]}" "${test_args[@]}" test

if [[ -n "$archive_path" ]]; then
  app="$simulator_build/Build/Products/Debug-iphonesimulator/BodyNote.app"
  platform=$(plutil -extract CFBundleSupportedPlatforms.0 raw -o - "$app/Info.plist")
  if [[ "$platform" != iPhoneSimulator ]]; then
    echo "Expected the tested iPhone Simulator product, found $platform." >&2
    exit 1
  fi
  xcrun lipo "$app/BodyNote" -verify_arch arm64
  python3 - "$app/Info.plist" <<'PYTHON'
import plistlib, sys
with open(sys.argv[1], "rb") as source:
    info = plistlib.load(source)
if set(info["UIDeviceFamily"]) != {1, 2}:
    sys.exit("Expected a universal iPhone and iPad app.")
orientations = info.get("UISupportedInterfaceOrientations~ipad", [])
if not {"UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"}.issubset(orientations):
    sys.exit("The iPad app must support both landscape orientations.")
PYTHON
  ditto -c -k --keepParent "$app" "$archive_path"
fi
