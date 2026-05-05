#!/bin/bash
# Build the Mac App Store variant without changing the Developer ID release lane.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PING_ISLAND_APP_STORE_BUILD_DIR:-$PROJECT_DIR/build/app-store}"
DERIVED_DATA_PATH="$BUILD_DIR/DerivedData"
ARCHIVE_PATH="$BUILD_DIR/PingIslandAppStore.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions-AppStore.plist"
TEAM_ID="${PING_ISLAND_TEAM_ID:-K46RM9974S}"
SCHEME="${PING_ISLAND_APP_STORE_SCHEME:-PingIslandAppStore}"
PROJECT_FILE="${PING_ISLAND_PROJECT_FILE:-PingIsland.xcodeproj}"
SKIP_SIGNING="${PING_ISLAND_SKIP_APP_STORE_SIGNING:-0}"
UPLOAD="${PING_ISLAND_APP_STORE_UPLOAD:-0}"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cd "$PROJECT_DIR"

archive_args=(
    xcodebuild archive
    -project "$PROJECT_FILE"
    -scheme "$SCHEME"
    -configuration Release
    -derivedDataPath "$DERIVED_DATA_PATH"
    -archivePath "$ARCHIVE_PATH"
    -destination "generic/platform=macOS"
)

if [ "$SKIP_SIGNING" = "1" ]; then
    archive_args+=(CODE_SIGNING_ALLOWED=NO)
else
    archive_args+=(
        -allowProvisioningUpdates
        CODE_SIGN_STYLE=Automatic
        DEVELOPMENT_TEAM="$TEAM_ID"
    )
fi

echo "Archiving Mac App Store build..."
"${archive_args[@]}"

if [ "$SKIP_SIGNING" = "1" ]; then
    echo "Archive created without signing at: $ARCHIVE_PATH"
    exit 0
fi

cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>export</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>uploadSymbols</key>
    <true/>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
</dict>
</plist>
EOF

if [ "$UPLOAD" = "1" ]; then
    /usr/libexec/PlistBuddy -c "Set :destination upload" "$EXPORT_OPTIONS"
fi

echo "Exporting Mac App Store build..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates

echo "Mac App Store export complete: $EXPORT_PATH"
