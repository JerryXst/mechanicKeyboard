#!/bin/zsh
set -euo pipefail

APP_NAME="MechanicKeyboard"
CONFIGURATION="release"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/.build/$CONFIGURATION"
APP_DIR="$ROOT_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BUNDLE_ID="${BUNDLE_ID:-com.jerryxst.mechanickeyboard}"
VERSION="${VERSION:-0.3.0}"
BUILD_NUMBER="${BUILD_NUMBER:-3}"

swift build -c "$CONFIGURATION"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR/sounds"
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
strip -x "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/sounds/default.wav" "$RESOURCES_DIR/sounds/default.wav"
for lproj in "$ROOT_DIR/AppStore"/*.lproj; do
    [[ -d "$lproj" ]] && cp -R "$lproj" "$RESOURCES_DIR/"
done

ICONSET_TMP="$(mktemp -d /tmp/mechanic-keyboard-icon.XXXXXX)/AppIcon.iconset"
mkdir -p "$ICONSET_TMP"
cp "$ROOT_DIR/AppStore/Assets.xcassets/AppIcon.appiconset"/icon_*.png "$ICONSET_TMP/"
iconutil -c icns "$ICONSET_TMP" -o "$RESOURCES_DIR/AppIcon.icns"
rm -rf "$(dirname "$ICONSET_TMP")"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>zh-Hans</string>
        <string>zh-Hant</string>
    </array>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Mechanic Keyboard</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSInputMonitoringUsageDescription</key>
    <string>Mechanic Keyboard listens for key presses to play typing sound effects.</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026</string>
</dict>
</plist>
PLIST

# Prefer a valid (non-revoked) Apple Development identity so macOS TCC (Input Monitoring)
# remembers the app across rebuilds. Revoked Apple certs trigger a fake "malware" alert on macOS.
sign_app() {
    local identity="$1"
    codesign --force --deep --options runtime --sign "$identity" "$APP_DIR"
}

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    echo "Signing with explicit identity: $CODESIGN_IDENTITY"
    sign_app "$CODESIGN_IDENTITY"
else
    signed=0
    while IFS= read -r candidate; do
        [[ -z "$candidate" ]] && continue
        sign_app "$candidate"
        check_out="$(spctl -a -vvv -t exec "$APP_DIR" 2>&1 || true)"
        if [[ "$check_out" != *"CERT_REVOKED"* ]]; then
            echo "Signed with valid identity: $candidate"
            signed=1
            break
        else
            echo "Skipping revoked certificate: $candidate"
        fi
    done < <(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development:/ {print $2}')

    if [[ "$signed" -eq 0 ]]; then
        echo "No non-revoked Apple Development certificate found; falling back to ad-hoc signature (-)"
        sign_app "-"
    fi
fi

xattr -cr "$APP_DIR"

echo "Built $APP_DIR"
