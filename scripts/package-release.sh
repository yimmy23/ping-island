#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/lib/dmg-layout.sh"

BUILD_DIR="${PING_ISLAND_BUILD_DIR:-$PROJECT_DIR/build/release}"
DERIVED_DATA_PATH="$BUILD_DIR/DerivedData"
EXPORT_PATH="$BUILD_DIR/export"
RELEASE_DIR="${PING_ISLAND_RELEASE_DIR:-$PROJECT_DIR/releases/signed}"
NOTES_DIR="$PROJECT_DIR/releases/notes"
KEYS_DIR="$PROJECT_DIR/.sparkle-keys"
STAGING_DIR="$BUILD_DIR/dmg-staging"

APP_BUNDLE_NAME="Ping Island.app"
APP_PRODUCT_NAME="PingIsland"
APP_PATH="$EXPORT_PATH/$APP_BUNDLE_NAME"

NOTARY_APPLE_ID="${PING_ISLAND_NOTARY_APPLE_ID:-${APPLE_ID:-}}"
NOTARY_TEAM_ID="${PING_ISLAND_NOTARY_TEAM_ID:-${APPLE_TEAM_ID:-}}"
NOTARY_PASSWORD="${PING_ISLAND_NOTARY_PASSWORD:-${APPLE_APP_SPECIFIC_PASSWORD:-}}"
NOTARY_KEYCHAIN_PROFILE="${PING_ISLAND_NOTARY_KEYCHAIN_PROFILE:-${NOTARY_KEYCHAIN_PROFILE:-PingIsland}}"
SKIP_NOTARIZATION="${PING_ISLAND_SKIP_NOTARIZATION:-0}"

SPARKLE_PRIVATE_KEY_PATH="${PING_ISLAND_SPARKLE_PRIVATE_KEY_PATH:-$KEYS_DIR/eddsa_private_key}"
GENERATE_APPCAST="${PING_ISLAND_GENERATE_APPCAST:-0}"
VALIDATE_RELEASE_PROGRESS="${PING_ISLAND_VALIDATE_RELEASE_PROGRESS:-1}"

notary_args=()

log_section() {
    echo ""
    echo "=== $1 ==="
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "ERROR: Missing required command: $1"
        exit 1
    fi
}

infer_github_repo() {
    if [ -n "${PING_ISLAND_GITHUB_REPO:-}" ]; then
        echo "$PING_ISLAND_GITHUB_REPO"
        return 0
    fi

    if [ -n "${GITHUB_REPOSITORY:-}" ]; then
        echo "$GITHUB_REPOSITORY"
        return 0
    fi

    local remote_url
    remote_url=$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null || true)

    if [[ "$remote_url" =~ github\.com[:/]([^/]+/[^/.]+)(\.git)?$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    return 1
}

resolve_notary_credentials() {
    if [ "$SKIP_NOTARIZATION" = "1" ]; then
        return
    fi

    if [ -n "$NOTARY_APPLE_ID" ] && [ -n "$NOTARY_TEAM_ID" ] && [ -n "$NOTARY_PASSWORD" ]; then
        notary_args=(
            --apple-id "$NOTARY_APPLE_ID"
            --team-id "$NOTARY_TEAM_ID"
            --password "$NOTARY_PASSWORD"
        )
        return
    fi

    if xcrun notarytool history --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" >/dev/null 2>&1; then
        notary_args=(--keychain-profile "$NOTARY_KEYCHAIN_PROFILE")
        return
    fi

    echo "ERROR: No usable notarization credentials were found."
    echo "Provide one of:"
    echo "  1. PING_ISLAND_NOTARY_APPLE_ID / PING_ISLAND_NOTARY_TEAM_ID / PING_ISLAND_NOTARY_PASSWORD"
    echo "  2. A notarytool keychain profile named '$NOTARY_KEYCHAIN_PROFILE'"
    echo ""
    echo "You can skip notarization explicitly with PING_ISLAND_SKIP_NOTARIZATION=1."
    exit 1
}

notarize_and_staple() {
    local submit_path="$1"
    local staple_path="$2"

    if [ "$SKIP_NOTARIZATION" = "1" ]; then
        echo "Skipping notarization for $submit_path"
        return
    fi

    echo "Submitting $(basename "$submit_path") for notarization..."
    local submit_result
    submit_result=$(xcrun notarytool submit "$submit_path" "${notary_args[@]}" --wait --output-format json)

    local submission_id
    submission_id=$(python3 - <<'PY' "$submit_result"
import json, sys
payload = json.loads(sys.argv[1])
print(payload.get("id", ""))
PY
)

    local status
    status=$(python3 - <<'PY' "$submit_result"
import json, sys
payload = json.loads(sys.argv[1])
print(payload.get("status", ""))
PY
)

    if [ "$status" != "Accepted" ]; then
        echo "ERROR: Notarization failed with status: $status"
        if [ -n "$submission_id" ]; then
            echo "Fetching notarization log for submission: $submission_id"
            xcrun notarytool log "$submission_id" "${notary_args[@]}" || true
        fi
        exit 1
    fi

    echo "Stapling $(basename "$staple_path")..."
    xcrun stapler staple "$staple_path"
    xcrun stapler validate "$staple_path"
}

find_sparkle_bin_dir() {
    shopt -s nullglob
    local candidates=(
        "$DERIVED_DATA_PATH/SourcePackages/artifacts/sparkle/Sparkle/bin"
        "$HOME/Library/Developer/Xcode/DerivedData/PingIsland-*/SourcePackages/artifacts/sparkle/Sparkle/bin"
        "$PROJECT_DIR/.build/artifacts/sparkle/Sparkle/bin"
    )

    for candidate in "${candidates[@]}"; do
        if [ -x "$candidate/generate_appcast" ] && [ -x "$candidate/sign_update" ]; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

generate_sparkle_appcast() {
    if [ "$GENERATE_APPCAST" != "1" ]; then
        return
    fi

    log_section "Generating Sparkle Appcast"

    if [ ! -f "$SPARKLE_PRIVATE_KEY_PATH" ]; then
        echo "ERROR: Sparkle private key not found at $SPARKLE_PRIVATE_KEY_PATH"
        exit 1
    fi

    local sparkle_bin_dir
    if ! sparkle_bin_dir="$(find_sparkle_bin_dir)"; then
        echo "ERROR: Could not find Sparkle tools in DerivedData or local artifacts."
        exit 1
    fi

    local appcast_dir="$RELEASE_DIR/appcast"
    mkdir -p "$appcast_dir"

    cp "$DMG_PATH" "$appcast_dir/"
    if [ -f "$NOTES_ASSET_PATH" ]; then
        cp "$NOTES_ASSET_PATH" "$appcast_dir/"
    fi

    "$sparkle_bin_dir/generate_appcast" \
        --ed-key-file "$SPARKLE_PRIVATE_KEY_PATH" \
        "$appcast_dir"

    echo "Appcast generated at: $appcast_dir/appcast.xml"
}

validate_embedded_sparkle_configuration() {
    local info_plist="$APP_PATH/Contents/Info.plist"
    local feed_url
    local public_key

    feed_url=$(/usr/libexec/PlistBuddy -c "Print :SUFeedURL" "$info_plist" 2>/dev/null || true)
    public_key=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$info_plist" 2>/dev/null || true)

    if [ -z "$feed_url" ] || [ -z "$public_key" ]; then
        echo "ERROR: Sparkle update configuration is missing from the exported app bundle."
        echo "ERROR: SUFeedURL='$feed_url'"
        echo "ERROR: SUPublicEDKey present=$([ -n "$public_key" ] && echo yes || echo no)"
        exit 1
    fi

    if [[ "$feed_url" != *"://"* ]]; then
        echo "ERROR: Sparkle feed URL in the exported app bundle looks truncated: $feed_url"
        echo "ERROR: If this came from an xcconfig file, avoid raw // by composing the URL with a slash helper."
        exit 1
    fi
}

validate_release_progression() {
    if [ "$VALIDATE_RELEASE_PROGRESS" != "1" ]; then
        return
    fi

    if ! command -v gh >/dev/null 2>&1; then
        echo "WARNING: gh CLI not found; skipping published-release version progression check."
        return
    fi

    local repo
    if ! repo="$(infer_github_repo)"; then
        echo "WARNING: Could not infer GitHub repository; skipping published-release version progression check."
        return
    fi

    local previous_release_tsv
    previous_release_tsv=$(gh api "repos/$repo/releases" --jq ".[] | select(.draft == false and .prerelease == false and .tag_name != \"v$VERSION\") | [.tag_name, (.assets[]? | select(.name | endswith(\".zip\")) | .browser_download_url)] | @tsv" | head -n 1)

    if [ -z "$previous_release_tsv" ]; then
        echo "No earlier published release found for version progression check."
        return
    fi

    local previous_tag previous_zip_url
    IFS=$'\t' read -r previous_tag previous_zip_url <<< "$previous_release_tsv"

    if [ -z "$previous_zip_url" ]; then
        echo "ERROR: Previous published release $previous_tag does not include a ZIP asset for comparison."
        exit 1
    fi

    local tmp_dir previous_plist previous_version previous_build
    tmp_dir=$(mktemp -d)
    previous_plist="$tmp_dir/previous-Info.plist"

    curl -fsSL "$previous_zip_url" -o "$tmp_dir/previous.zip"
    unzip -p "$tmp_dir/previous.zip" "Ping Island.app/Contents/Info.plist" > "$previous_plist"

    previous_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$previous_plist" 2>/dev/null || true)
    previous_build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$previous_plist" 2>/dev/null || true)

    rm -rf "$tmp_dir"

    if [ -z "$previous_version" ] || [ -z "$previous_build" ]; then
        echo "ERROR: Could not read version metadata from previous published release $previous_tag."
        exit 1
    fi

    python3 - <<'PY' "$VERSION" "$BUILD" "$previous_version" "$previous_build" "$previous_tag"
import sys

current_version, current_build, previous_version, previous_build, previous_tag = sys.argv[1:]

def normalize(value: str):
    try:
        return tuple(int(part) for part in value.split("."))
    except ValueError:
        print(f"ERROR: Non-numeric version component encountered in '{value}'.", file=sys.stderr)
        sys.exit(1)

if normalize(current_version) < normalize(previous_version):
    print(
        f"ERROR: Current short version {current_version} is older than published {previous_tag} ({previous_version}).",
        file=sys.stderr,
    )
    sys.exit(1)

if normalize(current_build) <= normalize(previous_build):
    print(
        f"ERROR: Current build {current_build} must be greater than published {previous_tag} build {previous_build}.",
        file=sys.stderr,
    )
    sys.exit(1)
PY
}

require_command xcodebuild
require_command xcrun
require_command ditto
require_command hdiutil
require_command codesign
require_command spctl
require_command swift
require_command python3

resolve_notary_credentials

echo "=== Packaging Signed Ping Island ==="
echo ""

export PING_ISLAND_BUILD_DIR="$BUILD_DIR"
export PING_ISLAND_DMG_FAIL_ON_PLAIN=1
"$SCRIPT_DIR/build.sh"

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: App bundle not found at $APP_PATH"
    exit 1
fi

log_section "Verifying App Signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist")

validate_release_progression

mkdir -p "$RELEASE_DIR"

ZIP_PATH="$RELEASE_DIR/$APP_PRODUCT_NAME-$VERSION.zip"
DMG_PATH="$RELEASE_DIR/$APP_PRODUCT_NAME-$VERSION.dmg"
NOTES_PATH="$NOTES_DIR/$VERSION.md"
NOTES_ASSET_PATH="$RELEASE_DIR/$APP_PRODUCT_NAME-$VERSION.md"
NOTARY_ZIP_PATH="$BUILD_DIR/$APP_PRODUCT_NAME-$VERSION-notarization.zip"

rm -f "$ZIP_PATH" "$DMG_PATH" "$NOTARY_ZIP_PATH"
rm -rf "$STAGING_DIR"

log_section "Notarizing App Bundle"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$NOTARY_ZIP_PATH"
notarize_and_staple "$NOTARY_ZIP_PATH" "$APP_PATH"
rm -f "$NOTARY_ZIP_PATH"

if [ "$SKIP_NOTARIZATION" != "1" ]; then
    log_section "Assessing Notarized App"
    spctl --assess --type execute -vv "$APP_PATH"
fi

log_section "Creating ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

log_section "Creating DMG"
create_styled_dmg "$APP_PATH" "$DMG_PATH" "Ping Island" "$STAGING_DIR" "$PROJECT_DIR"

notarize_and_staple "$DMG_PATH" "$DMG_PATH"
if [ "$SKIP_NOTARIZATION" != "1" ]; then
    if ! spctl --assess --type open -vv "$DMG_PATH"; then
        echo "WARNING: Gatekeeper assessment for the notarized DMG returned a non-zero exit code in this environment."
        echo "WARNING: Continuing because notarization and stapling for the DMG already succeeded."
    fi
fi

if [ -f "$NOTES_PATH" ]; then
    cp "$NOTES_PATH" "$NOTES_ASSET_PATH"
    echo "Release notes copied: $NOTES_ASSET_PATH"
fi

if [ "$GENERATE_APPCAST" = "1" ]; then
    validate_embedded_sparkle_configuration
fi

generate_sparkle_appcast

echo ""
echo "=== Signed Package Ready ==="
echo "Version: $VERSION ($BUILD)"
echo "App: $APP_PATH"
echo "ZIP: $ZIP_PATH"
echo "DMG: $DMG_PATH"
