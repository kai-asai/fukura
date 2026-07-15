#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="fukura.app"
APP_DIR="$SCRIPT_DIR/dist/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"

swift build --package-path "$SCRIPT_DIR" -c release

rm -rf "$SCRIPT_DIR/dist"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$SCRIPT_DIR/.build/release/FukuraMac" "$CONTENTS_DIR/MacOS/"
cp "$SCRIPT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$SCRIPT_DIR/Resources/Fukura.icns" "$CONTENTS_DIR/Resources/Fukura.icns"
cp "$SCRIPT_DIR/Resources/fukuraTemplate-18.png" "$CONTENTS_DIR/Resources/fukuraTemplate-18.png"
cp "$SCRIPT_DIR/Resources/fukuraTemplate-18@2x.png" "$CONTENTS_DIR/Resources/fukuraTemplate-18@2x.png"

SIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
if [ "$SIGN_IDENTITY" = "-" ]; then
  codesign --force --deep --sign - "$APP_DIR"
else
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
fi

if [ -n "${NOTARY_PROFILE:-}" ]; then
  NOTARY_ZIP="$SCRIPT_DIR/dist/fukura-mac.notary.zip"
  ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$NOTARY_ZIP"
  xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_DIR"
  rm -f "$NOTARY_ZIP"
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$SCRIPT_DIR/dist/fukura-mac.zip"

echo "Created: $APP_DIR"
echo "Created: $SCRIPT_DIR/dist/fukura-mac.zip"
