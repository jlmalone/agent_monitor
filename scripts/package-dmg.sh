#!/bin/bash
# Package AgentMonitor.app into a DMG for distribution

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

APP_NAME="AgentMonitor"
VERSION="1.0.0"
CONFIGURATION="${1:-Debug}"

# Try DerivedData first
APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/${CONFIGURATION}/${APP_NAME}.app" -type d 2>/dev/null | head -1)

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: Could not find ${APP_NAME}.app for ${CONFIGURATION} configuration"
    echo "   Build the app first: cd app && xcodebuild -project AgentMonitor.xcodeproj -scheme AgentMonitor -configuration ${CONFIGURATION} build"
    exit 1
fi

echo "📦 Found app at: $APP_PATH"

DMG_NAME="${APP_NAME}.dmg"
DMG_TEMP="${APP_NAME}-temp.dmg"
VOLUME_NAME="${APP_NAME}"
DIST_DIR="${PROJECT_ROOT}/dist"

mkdir -p "$DIST_DIR"
cd "$DIST_DIR"

# Clean up any existing DMG
rm -f "${DMG_NAME}" "${DMG_TEMP}"
hdiutil detach "/Volumes/${VOLUME_NAME}" 2>/dev/null || true

echo "📦 Creating DMG..."

# Create temporary directory for DMG contents
TMP_DIR=$(mktemp -d)

# Copy app to dist and temp
rm -rf "${DIST_DIR}/${APP_NAME}.app"
cp -R "${APP_PATH}" "${DIST_DIR}/"
cp -R "${APP_PATH}" "${TMP_DIR}/"

# Create symlink to Applications folder
ln -s /Applications "${TMP_DIR}/Applications"

# Create a read-write DMG first
hdiutil create -volname "${VOLUME_NAME}" \
    -srcfolder "${TMP_DIR}" \
    -ov -format UDRW \
    "${DMG_TEMP}"

# Clean up temp folder
rm -rf "${TMP_DIR}"

# Convert to compressed read-only DMG
echo "📀 Converting to compressed DMG..."
hdiutil convert "${DMG_TEMP}" -format UDZO -o "${DMG_NAME}"

# Clean up temp DMG
rm -f "${DMG_TEMP}"

echo ""
echo "✅ Created ${DIST_DIR}/${DMG_NAME}"
ls -lh "${DIST_DIR}/${DMG_NAME}"
ls -lh "${DIST_DIR}/${APP_NAME}.app"
echo ""
echo "To install: open ${DIST_DIR}/${DMG_NAME}"
