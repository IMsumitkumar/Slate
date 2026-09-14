#!/bin/bash
set -euo pipefail

# build.sh — Archive and package Slate into an ad-hoc signed DMG.
#
# Usage: ./scripts/build.sh
#
# Reads version from project.yml. Needs no .env and no Apple Developer account:
# Slate is ad-hoc signed, so there is nothing to notarize and nothing to staple.
# Users open the first launch with right-click → Open.
#
# Output: build/Slate-<version>.dmg

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

VERSION=$(grep "MARKETING_VERSION:" project.yml | sed 's/.*MARKETING_VERSION: //' | tr -d ' ')
DMG_NAME="Slate-${VERSION}.dmg"
ARCHIVE_PATH="build/Slate.xcarchive"

step "Building Slate v${VERSION}"

# Clean build dir (preserve root appcast and public key)
[[ -f appcast.xml ]] && cp appcast.xml /tmp/slate_appcast_backup.xml || true
[[ -f slate_public_key.pem ]] && cp slate_public_key.pem /tmp/slate_public_key_backup.pem || true
rm -rf build/
mkdir -p build
[[ -f /tmp/slate_appcast_backup.xml ]] && mv /tmp/slate_appcast_backup.xml appcast.xml || true
[[ -f /tmp/slate_public_key_backup.pem ]] && mv /tmp/slate_public_key_backup.pem slate_public_key.pem || true

echo "Generating Xcode project..."
xcodegen

echo "Archiving (this may take a few minutes)..."
if command -v xcbeautify >/dev/null 2>&1; then
    xcodebuild archive \
        -scheme Slate \
        -configuration Release \
        -destination "platform=macOS" \
        -archivePath "$ARCHIVE_PATH" \
        2>&1 | xcbeautify
else
    xcodebuild archive \
        -scheme Slate \
        -configuration Release \
        -destination "platform=macOS" \
        -archivePath "$ARCHIVE_PATH"
fi

[[ -d "$ARCHIVE_PATH" ]] || die "Archive failed — ${ARCHIVE_PATH} not found."

# Ad-hoc builds are already signed by the build itself, so there is no
# -exportArchive step: exporting requires a Developer ID identity we do not have.
APP_PATH="$ARCHIVE_PATH/Products/Applications/Slate.app"
[[ -d "$APP_PATH" ]] || die "Archive did not contain Slate.app at ${APP_PATH}."

echo "Copying app bundle out of the archive..."
ditto "$APP_PATH" "build/Slate.app"

echo "Verifying ad-hoc signature..."
codesign --verify --deep --strict --verbose=2 "build/Slate.app" || die "Signature verification failed."
codesign -dv "build/Slate.app" 2>&1 | grep -q "Signature=adhoc" || die "Expected an ad-hoc signature."

# --- Package ---

step "Packaging"

command -v create-dmg >/dev/null || die "create-dmg not found. Install with: brew install create-dmg"

echo "Creating DMG..."
create-dmg \
    --app-drop-link 600 185 \
    --window-size 800 400 \
    --volname "Slate" \
    --skip-jenkins \
    "build/${DMG_NAME}" \
    "build/Slate.app" 2>/dev/null || true

# create-dmg sometimes uses a temp name
TEMP_DMG=$(/bin/ls build/rw.*.dmg 2>/dev/null | head -1 || true)
[[ -n "$TEMP_DMG" ]] && mv "$TEMP_DMG" "build/${DMG_NAME}"
[[ -f "build/${DMG_NAME}" ]] || die "DMG creation failed."

echo "Ad-hoc signing DMG..."
codesign -f -s - "build/${DMG_NAME}"

green "Build complete: build/${DMG_NAME} ($(du -h "build/${DMG_NAME}" | cut -f1))"
echo "Note: ad-hoc signed and not notarized — first launch needs right-click → Open."
