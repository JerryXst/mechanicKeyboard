#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT_DIR/MechanicKeyboard.xcodeproj"
SCHEME="MechanicKeyboard"
CONFIGURATION="Release"
ARCHIVE_DIR="$ROOT_DIR/build/AppStore"
ARCHIVE_PATH="$ARCHIVE_DIR/MechanicKeyboard.xcarchive"
EXPORT_PATH="$ARCHIVE_DIR/export"
BUNDLE_ID="${BUNDLE_ID:-com.jerryxst.mechanickeyboard}"

if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
    echo "Set DEVELOPMENT_TEAM to your Apple Developer Team ID before archiving." >&2
    echo "Example: DEVELOPMENT_TEAM=ABCDE12345 $0" >&2
    exit 2
fi

mkdir -p "$ARCHIVE_DIR"

xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE_PATH" \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    CODE_SIGN_STYLE=Automatic

if [[ "${1:-}" == "--export" ]]; then
    rm -rf "$EXPORT_PATH"
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$ROOT_DIR/AppStore/ExportOptions.plist"
fi

echo "Archive created at $ARCHIVE_PATH"
