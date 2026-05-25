#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
  echo "Usage: ./scripts/package-dmg.sh <version>"
  echo "Example: ./scripts/package-dmg.sh 1.0.0"
  exit 1
fi

PROJECT_NAME="Coollama"
SCHEME="Coollama"
CONFIGURATION="Release"
APP_NAME="Coollama.app"
VOL_NAME="Coollama"

BUILD_DIR="$ROOT_DIR/build"
DERIVED_DATA_DIR="$BUILD_DIR/DerivedData"
DMG_ROOT="$BUILD_DIR/dmgroot"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME"
DMG_PATH="$DIST_DIR/Coollama-$VERSION.dmg"
LOCAL_ENV="$ROOT_DIR/scripts/release.env"

if [[ -f "$LOCAL_ENV" ]]; then
  # shellcheck disable=SC1090
  source "$LOCAL_ENV"
fi

echo "==> Cleaning build output"
rm -rf "$DERIVED_DATA_DIR" "$DMG_ROOT"
mkdir -p "$DMG_ROOT" "$DIST_DIR"

echo "==> Building $SCHEME ($CONFIGURATION)"
xcodebuild \
  -project "$ROOT_DIR/$PROJECT_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH"
  exit 1
fi

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  echo "==> Signing app with Developer ID"
  codesign --force --deep --options runtime --timestamp \
    --sign "$DEVELOPER_ID_APPLICATION" \
    "$APP_PATH"

  echo "==> Verifying app signature"
  codesign --verify --deep --strict --verbose=2 "$APP_PATH"
else
  echo "==> Skipping Developer ID signing (DEVELOPER_ID_APPLICATION not set)"
fi

echo "==> Preparing DMG contents"
cp -R "$APP_PATH" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

echo "==> Creating DMG"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  echo "==> Signing DMG"
  codesign --force --timestamp \
    --sign "$DEVELOPER_ID_APPLICATION" \
    "$DMG_PATH"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  echo "==> Notarizing DMG with keychain profile: $NOTARY_PROFILE"
  xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

  echo "==> Stapling notarization ticket"
  xcrun stapler staple "$DMG_PATH"
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APP_SPECIFIC_PASSWORD:-}" ]]; then
  echo "==> Notarizing DMG with Apple ID credentials"
  xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APP_SPECIFIC_PASSWORD" \
    --wait

  echo "==> Stapling notarization ticket"
  xcrun stapler staple "$DMG_PATH"
else
  echo "==> Skipping notarization (NOTARY_PROFILE or Apple ID credentials not set)"
fi

echo "==> Verifying DMG"
hdiutil verify "$DMG_PATH"

echo "Done: $DMG_PATH"
