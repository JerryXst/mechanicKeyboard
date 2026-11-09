#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="MechanicKeyboard"
APP_DIR="$ROOT_DIR/$APP_NAME.app"
DMG_NAME="${DMG_NAME:-MechanicKeyboard-0.3.0}"
DMG_PATH="$ROOT_DIR/$DMG_NAME.dmg"
STAGE_DIR="$(mktemp -d /tmp/mechanic-keyboard-dmg.XXXXXX)"

cleanup() {
    rm -rf "$STAGE_DIR"
}
trap cleanup EXIT

"$ROOT_DIR/build_app.sh"

mkdir -p "$STAGE_DIR"
cp -R "$APP_DIR" "$STAGE_DIR/$APP_NAME.app"
ln -s /Applications "$STAGE_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "Mechanic Keyboard" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "DMG ready: $DMG_PATH"
