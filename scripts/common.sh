# Shared helpers for the Macchiato scripts. Sourced by them, not executed.
#
# shellcheck shell=bash disable=SC2034
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
BUILD_DIR="$ROOT/build"
APP_NAME="Macchiato"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

die() {
    echo "error: $*" >&2
    exit 1
}

log() {
    echo "==> $*" >&2
}

# Reads the optional signing settings. They are never part of the repository: the file named by
# MACCHIATO_SIGNING_ENV, or ${XDG_CONFIG_HOME:-$HOME/.config}/macchiato/signing.env, may set
#   MACCHIATO_CODESIGN_IDENTITY, MACCHIATO_TEAM_ID                  (default: the Developer ID in the keychain)
#   MACCHIATO_NOTARY_KEY (key file path), MACCHIATO_NOTARY_KEY_ID, MACCHIATO_NOTARY_ISSUER_FILE (file holding the
#   issuer ID)                                                    (notarization; skipped when absent)
# Sets SIGN_IDENTITY and SIGN_TEAM. Never print the notary values.
load_signing_env() {
    local file="${MACCHIATO_SIGNING_ENV:-${XDG_CONFIG_HOME:-$HOME/.config}/macchiato/signing.env}"
    unset MACCHIATO_CODESIGN_IDENTITY MACCHIATO_TEAM_ID MACCHIATO_NOTARY_KEY MACCHIATO_NOTARY_KEY_ID MACCHIATO_NOTARY_ISSUER_FILE
    if [[ -r "$file" ]]; then
        # shellcheck disable=SC1090
        source "$file"
    fi
    SIGN_IDENTITY="${MACCHIATO_CODESIGN_IDENTITY:-}"
    SIGN_TEAM="${MACCHIATO_TEAM_ID:-}"
    if [[ -z "$SIGN_IDENTITY" ]]; then
        local line
        line="$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -n 1 || true)"
        [[ -n "$line" ]] || die "no Developer ID Application identity found (set MACCHIATO_CODESIGN_IDENTITY in $file)"
        SIGN_IDENTITY="$(sed -E 's/^[^"]*"([^"]+)".*$/\1/' <<<"$line")"
    fi
    if [[ -z "$SIGN_TEAM" ]]; then
        SIGN_TEAM="$(sed -E 's/^.*\(([A-Z0-9]+)\)$/\1/' <<<"$SIGN_IDENTITY")"
    fi
}

# generate_project: regenerates Macchiato.xcodeproj from project.yml.
generate_project() {
    command -v xcodegen >/dev/null || die "xcodegen is required (brew install xcodegen)"
    (cd "$ROOT" && xcodegen generate >/dev/null) || die "xcodegen failed"
}
