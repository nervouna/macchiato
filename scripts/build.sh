#!/usr/bin/env bash
# Builds build/Macchiato.app.
#   scripts/build.sh [debug|release]
# debug is ad-hoc signed. release is signed with the Developer ID identity (hardened runtime,
# secure timestamp) so it can be notarized by scripts/release.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

CONFIG="${1:-debug}"
case "$CONFIG" in
    debug) XCODE_CONFIG=Debug ;;
    release) XCODE_CONFIG=Release ;;
    *) die "usage: $0 [debug|release]" ;;
esac

generate_project
SIGNING_ARGS=()
if [[ "$CONFIG" == release ]]; then
    load_signing_env
    log "signing as: $SIGN_IDENTITY"
    SIGNING_ARGS=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=$SIGN_IDENTITY" "DEVELOPMENT_TEAM=$SIGN_TEAM"
        "OTHER_CODE_SIGN_FLAGS=--timestamp" CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO)
fi

log "building $XCODE_CONFIG"
xcodebuild -project "$ROOT/Macchiato.xcodeproj" -scheme "$APP_NAME" -configuration "$XCODE_CONFIG" \
    -derivedDataPath "$BUILD_DIR/derived" ${SIGNING_ARGS[@]+"${SIGNING_ARGS[@]}"} build -quiet \
    || die "xcodebuild failed"

rm -rf "$APP_BUNDLE"
cp -R "$BUILD_DIR/derived/Build/Products/$XCODE_CONFIG/$APP_NAME.app" "$APP_BUNDLE"
codesign --verify --strict --deep "$APP_BUNDLE" || die "signature check failed"
if [[ "$CONFIG" == release ]]; then
    DETAILS="$(codesign -dv "$APP_BUNDLE" 2>&1)"
    [[ "$DETAILS" == *"flags="*"runtime"* ]] || die "hardened runtime is missing"
    ENTITLEMENTS="$(codesign -d --entitlements - "$APP_BUNDLE" 2>&1)"
    [[ "$ENTITLEMENTS" != *get-task-allow* ]] || die "the release requests get-task-allow (notarization rejects it)"
fi
log "built $APP_BUNDLE"
