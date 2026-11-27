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

simulator=$(xcrun simctl list devices available --json | python3 -c '
import json, re, sys
phones = []
for runtime, devices in json.load(sys.stdin)["devices"].items():
    match = re.fullmatch(r"com\.apple\.CoreSimulator\.SimRuntime\.iOS-(\d+(?:-\d+)*)", runtime)
    if match:
        version = tuple(map(int, match[1].split("-")))
        for device in devices:
            if version[0] >= 26 and device["name"].startswith("iPhone") and device["isAvailable"]:
                phones.append((version, device["state"] == "Booted", device["udid"]))
if not phones:
    sys.exit("Install an iOS 26 or newer iPhone simulator in Xcode Settings > Components.")
print(max(phones)[2])
')

# Wait for SpringBoard and the simulator services before XCTest launches the app.
xcrun simctl bootstatus "$simulator" -b

result_path=${WORKOUT_UI_RESULT_PATH:-"$(mktemp -d)/WorkoutLog.xcresult"}
test_args=(-configuration Debug -destination "platform=iOS Simulator,id=$simulator,arch=$(uname -m)"
  -parallel-testing-enabled NO -resultBundlePath "$result_path")
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
  ditto -c -k --keepParent "$app" "$archive_path"
fi
