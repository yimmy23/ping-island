#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKGROUND_GENERATOR="$SCRIPT_DIR/generate-dmg-background.swift"
DMG_ICON_PNG="${PING_ISLAND_DMG_ICON_PNG:-$PROJECT_DIR/PingIsland/Assets.xcassets/AppIcon.appiconset/icon_512x512.png}"

VOLNAME=""
SOURCE_DIR=""
OUTPUT_DMG=""
APP_NAME="Ping Island.app"
WINDOW_WIDTH="${PING_ISLAND_DMG_WINDOW_WIDTH:-520}"
WINDOW_HEIGHT="${PING_ISLAND_DMG_WINDOW_HEIGHT:-360}"
ICON_SIZE="${PING_ISLAND_DMG_ICON_SIZE:-92}"
APP_X="${PING_ISLAND_DMG_APP_X:-138}"
APP_Y="${PING_ISLAND_DMG_APP_Y:-168}"
APPLICATIONS_X="${PING_ISLAND_DMG_APPLICATIONS_X:-388}"
APPLICATIONS_Y="${PING_ISLAND_DMG_APPLICATIONS_Y:-168}"

usage() {
  cat <<'EOF'
Usage: create-styled-dmg.sh --volname <name> --source <folder> --output <dmg-path> [options]

Options:
  --app-name <bundle-name>       App bundle name inside the DMG
  --window-width <pixels>        Finder window width
  --window-height <pixels>       Finder window height
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --volname)
      VOLNAME="${2:-}"
      shift 2
      ;;
    --source)
      SOURCE_DIR="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_DMG="${2:-}"
      shift 2
      ;;
    --app-name)
      APP_NAME="${2:-}"
      shift 2
      ;;
    --window-width)
      WINDOW_WIDTH="${2:-}"
      shift 2
      ;;
    --window-height)
      WINDOW_HEIGHT="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$VOLNAME" || -z "$SOURCE_DIR" || -z "$OUTPUT_DMG" ]]; then
  usage >&2
  exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Source directory not found: $SOURCE_DIR" >&2
  exit 1
fi

if [[ ! -x "$BACKGROUND_GENERATOR" ]]; then
  chmod +x "$BACKGROUND_GENERATOR"
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ping-island-dmg.XXXXXX")"
RW_DMG="$TMP_DIR/styled.dmg"
MOUNT_POINT="$TMP_DIR/mount"
BACKGROUND_PATH="$TMP_DIR/background.png"
ICON_WORK_PNG="$TMP_DIR/dmg-icon.png"
ICON_RESOURCE_PATH="$TMP_DIR/dmg-icon.rsrc"
LAYOUT_READY=0
ATTACHED=0

cleanup() {
  if [[ "$ATTACHED" -eq 1 ]]; then
    hdiutil detach "$MOUNT_POINT" -quiet >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

SOURCE_SIZE_MB=$(du -sk "$SOURCE_DIR" | awk '{ printf "%d", ($1 / 1024) + 80 }')
mkdir -p "$MOUNT_POINT"
rm -f "$OUTPUT_DMG"

swift "$BACKGROUND_GENERATOR" --output "$BACKGROUND_PATH" --width "$WINDOW_WIDTH" --height "$WINDOW_HEIGHT"

if [[ -f "$DMG_ICON_PNG" ]]; then
  cp "$DMG_ICON_PNG" "$ICON_WORK_PNG"
  sips -i "$ICON_WORK_PNG" >/dev/null
  DeRez -only icns "$ICON_WORK_PNG" > "$ICON_RESOURCE_PATH"
fi

hdiutil create \
  -srcfolder "$SOURCE_DIR" \
  -volname "$VOLNAME" \
  -fs HFS+ \
  -format UDRW \
  -size "${SOURCE_SIZE_MB}m" \
  -ov \
  "$RW_DMG" >/dev/null

hdiutil attach \
  -readwrite \
  -noverify \
  -noautoopen \
  -mountpoint "$MOUNT_POINT" \
  "$RW_DMG" >/dev/null
ATTACHED=1

mkdir -p "$MOUNT_POINT/.background"
cp "$BACKGROUND_PATH" "$MOUNT_POINT/.background/background.png"

if [[ -f "$ICON_RESOURCE_PATH" ]]; then
  local_volume_icon="$MOUNT_POINT/Icon"$'\r'
  Rez -append "$ICON_RESOURCE_PATH" -o "$local_volume_icon"
  xcrun SetFile -a V "$local_volume_icon"
  xcrun SetFile -a C "$MOUNT_POINT"
fi

if osascript <<EOF
tell application "Finder"
  repeat 20 times
    if exists disk "$VOLNAME" then exit repeat
    delay 0.5
  end repeat

  if not (exists disk "$VOLNAME") then error "Disk $VOLNAME not visible in Finder"

  tell disk "$VOLNAME"
    open
    delay 1
    set current view of container window to icon view
    try
      set toolbar visible of container window to false
    end try
    try
      set statusbar visible of container window to false
    end try
    set bounds of container window to {120, 120, 120 + $WINDOW_WIDTH, 120 + $WINDOW_HEIGHT}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to $ICON_SIZE
    set text size of theViewOptions to 13
    set background picture of theViewOptions to POSIX file "$MOUNT_POINT/.background/background.png" as alias
    set position of item "$APP_NAME" of container window to {$APP_X, $APP_Y}
    set position of item "Applications" of container window to {$APPLICATIONS_X, $APPLICATIONS_Y}
    close
    open
    update without registering applications
    delay 2
  end tell
end tell
EOF
then
  LAYOUT_READY=1
else
  echo "warning: Finder customization failed; falling back to a plain DMG layout" >&2
fi

sync
hdiutil detach "$MOUNT_POINT" >/dev/null
ATTACHED=0

hdiutil convert \
  "$RW_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  -o "$OUTPUT_DMG" >/dev/null

if [[ -f "$ICON_RESOURCE_PATH" ]]; then
  Rez -append "$ICON_RESOURCE_PATH" -o "$OUTPUT_DMG"
  xcrun SetFile -a C "$OUTPUT_DMG"
fi

if [[ "$LAYOUT_READY" -eq 1 ]]; then
  echo "Styled DMG created at $OUTPUT_DMG"
else
  echo "DMG created without Finder styling at $OUTPUT_DMG"
fi
