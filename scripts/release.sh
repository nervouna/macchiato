#!/usr/bin/env bash
# Builds a Developer ID signed release and packages build/release/Macchiato-<version>.zip.
#   scripts/release.sh [--skip-notarize]
# Notarizes and staples when MACCHIATO_NOTARY_KEY, _KEY_ID and _ISSUER_FILE are set (see scripts/common.sh);
# otherwise the zip is signed only, and the first launch on another Mac needs right-click > Open.
# The notary key file is passed to notarytool by path and never read here; the issuer ID is read into a
# variable that is never printed.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

SKIP_NOTARIZE=0
[[ "${1:-}" == "--skip-notarize" ]] && SKIP_NOTARIZE=1

"$ROOT/scripts/build.sh" release
load_signing_env

VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_BUNDLE/Contents/Info.plist")"
RELEASE_DIR="$BUILD_DIR/release"
ZIP="$RELEASE_DIR/$APP_NAME-$VERSION.zip"
mkdir -p "$RELEASE_DIR"
rm -f "$ZIP" "$ZIP.sha256"

NOTARIZE=0
NOTARY_ISSUER=""
if [[ $SKIP_NOTARIZE -eq 0 && -n "${MACCHIATO_NOTARY_KEY:-}" && -n "${MACCHIATO_NOTARY_KEY_ID:-}" && -n "${MACCHIATO_NOTARY_ISSUER_FILE:-}" ]]; then
    [[ -r "$MACCHIATO_NOTARY_KEY" ]] || die "the notary key file is not readable"
    [[ -r "$MACCHIATO_NOTARY_ISSUER_FILE" ]] || die "the notary issuer file is not readable"
    NOTARY_ISSUER="$(tr -d '[:space:]' <"$MACCHIATO_NOTARY_ISSUER_FILE")"
    [[ -n "$NOTARY_ISSUER" ]] || die "the notary issuer file is empty"
    NOTARIZE=1
fi

if [[ $NOTARIZE -eq 1 ]]; then
    SUBMIT_ZIP="$RELEASE_DIR/submit.zip"
    ditto -c -k --keepParent "$APP_BUNDLE" "$SUBMIT_ZIP"
    log "notarizing (this can take a few minutes)"
    xcrun notarytool submit "$SUBMIT_ZIP" --wait \
        --key "$MACCHIATO_NOTARY_KEY" --key-id "$MACCHIATO_NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER" \
        >"$RELEASE_DIR/notary.log" 2>&1 || { sed "s#$NOTARY_ISSUER#<issuer>#g" "$RELEASE_DIR/notary.log" >&2; die "notarization failed"; }
    grep -q "status: Accepted" "$RELEASE_DIR/notary.log" || die "notarization was not accepted (see $RELEASE_DIR/notary.log)"
    rm -f "$SUBMIT_ZIP"
    xcrun stapler staple "$APP_BUNDLE" >/dev/null || die "stapling failed"
    spctl --assess --type execute "$APP_BUNDLE" || die "Gatekeeper rejects the stapled app"
else
    log "not notarizing: the zip is signed only"
fi

ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP"
(cd "$RELEASE_DIR" && shasum -a 256 "$(basename "$ZIP")" >"$(basename "$ZIP").sha256")
log "packaged $ZIP"
