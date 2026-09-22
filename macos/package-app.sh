#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="fukura.app"
APP_DIR="$SCRIPT_DIR/dist/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"

# Validate release configuration before building or removing previous outputs.
python3 "$SCRIPT_DIR/configure-updates.py" --validate
swift build --package-path "$SCRIPT_DIR" -c release
BIN_DIR="$(swift build --package-path "$SCRIPT_DIR" -c release --show-bin-path)"

rm -rf "$SCRIPT_DIR/dist"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$BIN_DIR/FukuraMac" "$CONTENTS_DIR/MacOS/"
cp "$SCRIPT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$SCRIPT_DIR/Resources/Fukura.icns" "$CONTENTS_DIR/Resources/Fukura.icns"
cp "$SCRIPT_DIR/Resources/fukuraTemplate-18.png" "$CONTENTS_DIR/Resources/fukuraTemplate-18.png"
cp "$SCRIPT_DIR/Resources/fukuraTemplate-18@2x.png" "$CONTENTS_DIR/Resources/fukuraTemplate-18@2x.png"

python3 "$SCRIPT_DIR/configure-updates.py" "$CONTENTS_DIR/Info.plist"

# The binary SPM artifact includes the framework, helper apps, and symlinks.
SPARKLE_SOURCE="$(find "$SCRIPT_DIR/.build/artifacts" -type d -name Sparkle.framework -print)"
if [ -z "$SPARKLE_SOURCE" ] || [ ! -d "$SPARKLE_SOURCE" ]; then
  echo "Expected exactly one Sparkle.framework in SPM artifacts" >&2
  exit 1
fi
mkdir -p "$CONTENTS_DIR/Frameworks"
ditto "$SPARKLE_SOURCE" "$CONTENTS_DIR/Frameworks/Sparkle.framework"
SPARKLE_FRAMEWORK="$CONTENTS_DIR/Frameworks/Sparkle.framework"

SIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
SIGN_ARGS=(--force --sign "$SIGN_IDENTITY")
if [ "$SIGN_IDENTITY" != "-" ]; then
  SIGN_ARGS+=(--options runtime --timestamp)
fi
# Sign nested code from the inside out, not with --deep.
codesign "${SIGN_ARGS[@]}" "$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Installer.xpc"
codesign "${SIGN_ARGS[@]}" --preserve-metadata=entitlements "$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Downloader.xpc"
codesign "${SIGN_ARGS[@]}" "$SPARKLE_FRAMEWORK/Versions/B/Autoupdate"
codesign "${SIGN_ARGS[@]}" "$SPARKLE_FRAMEWORK/Versions/B/Updater.app"
codesign "${SIGN_ARGS[@]}" "$SPARKLE_FRAMEWORK"
codesign "${SIGN_ARGS[@]}" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

if [ -n "${NOTARY_PROFILE:-}" ]; then
  NOTARY_ZIP="$SCRIPT_DIR/dist/fukura-mac.notary.zip"
  ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$NOTARY_ZIP"
  xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_DIR"
  xcrun stapler validate "$APP_DIR"
  spctl --assess --type execute "$APP_DIR"
  rm -f "$NOTARY_ZIP"
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$SCRIPT_DIR/dist/fukura-mac.zip"

echo "Created: $APP_DIR"
echo "Created: $SCRIPT_DIR/dist/fukura-mac.zip"
