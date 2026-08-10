#!/usr/bin/env bash
# verify-assets.sh — check the vendored vis-network bundle matches the pinned
# hash and that no private content has leaked into Git-tracked paths.
# Used by CI (validate job) and safe to run locally. Read-only.

set -euo pipefail

SERVICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_JS_SHA256='576bb887733eb01bb52ee75b90ef46d818454de5fddb5b616fb8a298d307ca12'

echo "${EXPECTED_JS_SHA256}  ${SERVICE_DIR}/assets/vis-network.min.js" | sha256sum -c -

[ -f "${SERVICE_DIR}/assets/vis-network-LICENSE-APACHE-2.0.txt" ] || {
    echo "ERROR: vis-network license file missing" >&2
    exit 1
}

# The private generated site content must never be tracked in this public
# repo — reject ANY Git-tracked file under site/, not just index.html.
TRACKED_SITE_FILES="$(git -C "$SERVICE_DIR" ls-files -- site/)"
if [ -n "$TRACKED_SITE_FILES" ]; then
    echo "ERROR: files under site/ are tracked by Git — private content must not be committed:" >&2
    printf '%s\n' "$TRACKED_SITE_FILES" | sed 's/^/  /' >&2
    exit 1
fi

echo "OK: vendored assets verified, no private site content tracked"
