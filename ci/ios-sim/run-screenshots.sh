#!/bin/bash
# Build the frozen iOS 1.0 (2) app for the Simulator and capture screenshots.
# ios/project.yml is modified only in this working copy, then restored.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/ci/ios-sim/output"
rm -rf "$OUT"
mkdir -p "$OUT"

restore_spec() {
  git checkout -- ios/project.yml
}
trap restore_spec EXIT

grep -q '^    MARKETING_VERSION: 1.0$' ios/project.yml
grep -q '^    CURRENT_PROJECT_VERSION: 2$' ios/project.yml
python3 ci/ios-sim/inject_uitest.py

if command -v brew >/dev/null 2>&1; then
  brew list xcodegen >/dev/null 2>&1 || brew install xcodegen
fi
ios/generate-project.sh

pick_xcode() {
  local app
  app="$(ls -d /Applications/Xcode_16*.app 2>/dev/null | sort | tail -1 || true)"
  if [ -z "$app" ] && [ -d /Applications/Xcode.app ]; then
    app=/Applications/Xcode.app
  fi
  if [ -n "$app" ]; then
    sudo xcode-select -s "$app/Contents/Developer" || true
  fi
  xcodebuild -version | tee "$OUT/xcode-version.txt"
}
pick_xcode

DEVICE_LINE="$(xcrun simctl list devices available | awk '/iPhone/ && !/unavailable/ { print; exit }')"
echo "device line: $DEVICE_LINE" | tee "$OUT/device.txt"
UDID="$(printf '%s\n' "$DEVICE_LINE" | sed -n 's/.*(\([0-9A-F-]\{36\}\)).*/\1/p')"
if [ -z "$UDID" ]; then
  echo "No available iPhone simulator" >&2
  exit 1
fi
echo "$UDID" | tee "$OUT/udid.txt"

xcrun simctl boot "$UDID" || true
python3 - <<PY
import subprocess, sys
udid = "$UDID"
try:
    subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], timeout=180, check=True)
except subprocess.TimeoutExpired:
    sys.exit("simulator bootstatus timed out")
PY

DERIVED="$OUT/Derived"
xcodebuild \
  -project ios/Fukura.xcodeproj \
  -scheme Fukura \
  -derivedDataPath "$DERIVED" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  build-for-testing \
  -resultBundlePath "$OUT/Build.xcresult"

APP="$(find "$DERIVED" -path '*Debug-iphonesimulator/Fukura.app' -type d | head -1)"
if [ -z "$APP" ]; then
  echo "Fukura.app was not produced" >&2
  exit 1
fi
echo "$APP" | tee "$OUT/app-path.txt"
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" com.kaiasai.fukura
sleep 3

shot() {
  local name="$1"
  local dest="$OUT/$name"
  local attempt
  for attempt in 1 2 3; do
    if python3 - "$dest" <<'PY'
import subprocess, sys
dest = sys.argv[1]
try:
    subprocess.run(["xcrun", "simctl", "io", "booted", "screenshot", dest], timeout=25, check=True)
except subprocess.TimeoutExpired:
    raise SystemExit(1)
PY
    then
      return 0
    fi
    echo "screenshot attempt $attempt failed for $name" >&2
    sleep 2
  done
  return 1
}

shot "00-launch.png"

set +e
xcodebuild \
  -project ios/Fukura.xcodeproj \
  -scheme Fukura \
  -derivedDataPath "$DERIVED" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  test-without-building \
  -only-testing:FukuraScreenshots \
  -resultBundlePath "$OUT/Test.xcresult"
TEST_STATUS=$?
set -e
echo "uitest exit $TEST_STATUS" | tee "$OUT/uitest-exit.txt"

xcrun simctl spawn booted tar -c -C /tmp/fukura-screenshots . > "$OUT/sim-shots.tar" 2>/dev/null || true
if [ -s "$OUT/sim-shots.tar" ]; then
  tar -x -f "$OUT/sim-shots.tar" -C "$OUT" || true
fi

if [ -d "$OUT/Test.xcresult" ]; then
  xcrun xcresulttool export attachments --path "$OUT/Test.xcresult" --output-path "$OUT/attachments" \
    || xcrun xcresulttool export attachments --legacy --path "$OUT/Test.xcresult" --output-path "$OUT/attachments" \
    || true
fi

find "$OUT" -name '*.png' -print | tee "$OUT/png-list.txt"
test -f "$OUT/00-launch.png"
echo "screenshots ready in $OUT"
