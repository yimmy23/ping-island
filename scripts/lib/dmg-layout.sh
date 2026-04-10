#!/bin/bash

create_styled_dmg() {
    local app_path="$1"
    local dmg_path="$2"
    local volume_name="$3"
    local staging_dir="$4"
    local project_dir="$5"

    local background_source="${PING_ISLAND_DMG_BACKGROUND_SOURCE:-$project_dir/docs/images/ping-island-mascot-poster.png}"
    local background_dir_name=".background"
    local background_name="installer-background.png"
    local background_width="${PING_ISLAND_DMG_BACKGROUND_WIDTH:-680}"
    local background_height="${PING_ISLAND_DMG_BACKGROUND_HEIGHT:-440}"
    local window_left="${PING_ISLAND_DMG_WINDOW_LEFT:-160}"
    local window_top="${PING_ISLAND_DMG_WINDOW_TOP:-140}"
    local app_x="${PING_ISLAND_DMG_APP_X:-190}"
    local applications_x="${PING_ISLAND_DMG_APPLICATIONS_X:-490}"
    local icon_y="${PING_ISLAND_DMG_ICON_Y:-245}"
    local temp_dmg="${dmg_path%.dmg}-temp.dmg"
    local compressed_stem="${dmg_path%.dmg}"
    local mount_dir="$staging_dir/.mount"
    local window_right=$((window_left + background_width))
    local window_bottom=$((window_top + background_height))
    local app_name

    app_name="$(basename "$app_path")"

    for required_command in hdiutil osascript sips; do
        if ! command -v "$required_command" >/dev/null 2>&1; then
            echo "ERROR: Missing required command: $required_command"
            return 1
        fi
    done

    if [ ! -f "$background_source" ]; then
        echo "ERROR: DMG background image not found at $background_source"
        echo "Set PING_ISLAND_DMG_BACKGROUND_SOURCE to override the default asset."
        return 1
    fi

    rm -f "$dmg_path" "$temp_dmg"
    rm -rf "$staging_dir"

    mkdir -p "$staging_dir/$background_dir_name"
    cp -R "$app_path" "$staging_dir/"
    ln -s /Applications "$staging_dir/Applications"

    sips -z "$background_height" "$background_width" \
        "$background_source" \
        --out "$staging_dir/$background_dir_name/$background_name" \
        >/dev/null
    chflags hidden "$staging_dir/$background_dir_name"

    hdiutil create \
        -volname "$volume_name" \
        -srcfolder "$staging_dir" \
        -fs HFS+ \
        -format UDRW \
        -ov \
        "$temp_dmg" \
        >/dev/null

    mkdir -p "$mount_dir"
    hdiutil attach \
        -readwrite \
        -noverify \
        -noautoopen \
        -mountpoint "$mount_dir" \
        "$temp_dmg" \
        >/dev/null

    touch "$mount_dir/.DS_Store"

    osascript <<EOF
tell application "Finder"
    tell disk "$volume_name"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {$window_left, $window_top, $window_right, $window_bottom}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 16
        set background_alias to POSIX file "$mount_dir/$background_dir_name/$background_name" as alias
        set background picture of viewOptions to background_alias
        set position of item "$app_name" of container window to {$app_x, $icon_y}
        set position of item "Applications" of container window to {$applications_x, $icon_y}
        update without registering applications
        close
        open
        delay 2
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

    sync
    local detached=0
    for _ in 1 2 3; do
        if hdiutil detach "$mount_dir" >/dev/null 2>&1; then
            detached=1
            break
        fi
        sleep 1
    done

    if [ "$detached" != "1" ]; then
        echo "ERROR: Failed to detach DMG mount at $mount_dir"
        return 1
    fi

    rm -rf "$mount_dir"

    hdiutil convert \
        "$temp_dmg" \
        -format UDZO \
        -imagekey zlib-level=9 \
        -ov \
        -o "$compressed_stem" \
        >/dev/null

    rm -f "$temp_dmg"
    rm -rf "$staging_dir"
}
