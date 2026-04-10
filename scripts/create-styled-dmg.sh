#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VOLNAME=""
SOURCE_DIR=""
OUTPUT_PATH=""
APP_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --volname)
      VOLNAME="$2"
      shift 2
      ;;
    --source)
      SOURCE_DIR="$2"
      shift 2
      ;;
    --output)
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --app-name)
      APP_NAME="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$VOLNAME" || -z "$SOURCE_DIR" || -z "$OUTPUT_PATH" || -z "$APP_NAME" ]]; then
  echo "Usage: $0 --volname <name> --source <dir> --output <path> --app-name <bundle>" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
RW_DMG="$TMP_DIR/styled-rw.dmg"
MOUNT_INFO="$TMP_DIR/mount.plist"

cleanup() {
  if [[ -f "$MOUNT_INFO" ]]; then
    python3 - <<'PY' "$MOUNT_INFO" 2>/dev/null | while read -r mountpoint; do
import plistlib, sys
with open(sys.argv[1], 'rb') as f:
    data = plistlib.load(f)
for entity in data.get('system-entities', []):
    mount = entity.get('mount-point')
    if mount:
        print(mount)
PY
      if [[ -n "$mountpoint" ]]; then
        hdiutil detach "$mountpoint" -quiet || true
      fi
    done
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

rm -f "$OUTPUT_PATH"

hdiutil create \
  -srcfolder "$SOURCE_DIR" \
  -volname "$VOLNAME" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -format UDRW \
  -ov \
  "$RW_DMG" >/dev/null

hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen -plist > "$MOUNT_INFO"

MOUNT_POINT="$(python3 - <<'PY' "$MOUNT_INFO"
import plistlib, sys
with open(sys.argv[1], 'rb') as f:
    data = plistlib.load(f)
for entity in data.get('system-entities', []):
    mount = entity.get('mount-point')
    if mount:
        print(mount)
        break
PY
)"

if [[ -z "$MOUNT_POINT" ]]; then
  echo "Failed to determine DMG mount point" >&2
  exit 1
fi

mkdir -p "$MOUNT_POINT/.background"
swift "$SCRIPT_DIR/generate-dmg-background.swift" "$MOUNT_POINT/.background/background.png" "$VOLNAME"

APP_BUNDLE_PATH="$MOUNT_POINT/$APP_NAME"
if [[ -f "$APP_BUNDLE_PATH/Contents/Resources/AppIcon.icns" ]]; then
  cp "$APP_BUNDLE_PATH/Contents/Resources/AppIcon.icns" "$MOUNT_POINT/.VolumeIcon.icns"
  if command -v SetFile >/dev/null 2>&1; then
    SetFile -a C "$MOUNT_POINT" || true
  fi
fi

osascript <<OSA
tell application "Finder"
  tell disk "$VOLNAME"
    open
    delay 1
    tell container window
      set current view to icon view
      set toolbar visible to false
      set statusbar visible to false
      set bounds to {120, 120, 900, 620}
      set theViewOptions to the icon view options
      set arrangement of theViewOptions to not arranged
      set icon size of theViewOptions to 128
      set text size of theViewOptions to 14
      set background picture of theViewOptions to file ".background:background.png"
    end tell
    set position of item "$APP_NAME" to {210, 285}
    set position of item "Applications" to {600, 285}
    update without registering applications
    delay 2
    close
  end tell
end tell
OSA

hdiutil detach "$MOUNT_POINT" -quiet
rm -f "$MOUNT_INFO"

hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUTPUT_PATH" >/dev/null
