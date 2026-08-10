#!/usr/bin/env bash
# publish-graph-secrets.sh — package a locally generated Graphify graph.html
# and push it to GitHub Actions secrets, without the private HTML ever
# touching the public repo or the terminal.
#
# Usage:
#   ./publish-graph-secrets.sh /path/to/graph.html [--repo owner/repo]
#
# What it does:
#   1. Requires the HTML to reference exactly the pinned unpkg vis-network URL.
#   2. Rewrites that URL to the locally vendored /assets/vis-network.min.js.
#   3. Rejects any remaining external runtime references (src/href/url/@import
#      pointing at http://, https://, or protocol-relative //).
#   4. gzip + base64 encodes the transformed HTML.
#   5. Updates two repo secrets via `gh` stdin (values are never printed):
#        PROJECT_GRAPH_DASHBOARD_GZIP_B64   — gzipped+base64 transformed HTML
#        PROJECT_GRAPH_DASHBOARD_SHA256     — sha256 of the transformed HTML
#
# Only byte counts and the (non-secret) SHA-256 are printed.

set -euo pipefail
umask 077

# The one and only external URL Graphify output is allowed to contain.
# Must match the vendored bundle in ../assets/vis-network.min.js
# (sha256 576bb887733eb01bb52ee75b90ef46d818454de5fddb5b616fb8a298d307ca12).
PINNED_URL='https://unpkg.com/vis-network@9.1.6/standalone/umd/vis-network.min.js'
LOCAL_ASSET_PATH='/assets/vis-network.min.js'

SECRET_B64_NAME='PROJECT_GRAPH_DASHBOARD_GZIP_B64'
SECRET_SHA_NAME='PROJECT_GRAPH_DASHBOARD_SHA256'
# GitHub repository secrets are capped at 48 KiB.
MAX_SECRET_BYTES=$((48 * 1024))

REPO='AnandSingh/docker-configs'
GRAPH_HTML=''

usage() {
    grep '^#' "$0" | head -20 | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage 0 ;;
        --repo)
            [ $# -ge 2 ] || die "--repo requires a value"
            REPO="$2"
            shift 2
            ;;
        -*) die "Unknown option: $1" ;;
        *)
            [ -z "$GRAPH_HTML" ] || die "Unexpected extra argument: $1"
            GRAPH_HTML="$1"
            shift
            ;;
    esac
done

[ -n "$GRAPH_HTML" ] || usage 1
[ -f "$GRAPH_HTML" ] || die "File not found: $GRAPH_HTML"
command -v gh >/dev/null 2>&1 || die "GitHub CLI (gh) is required"
# Verify the active account can access the actual target repository. `gh auth
# status` may fail because of an unrelated stale inactive account even when the
# active account is valid, so it is not a reliable publication gate.
gh repo view "$REPO" --json nameWithOwner >/dev/null 2>&1 || \
    die "gh cannot access ${REPO} with the active account (check: gh auth status)"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# --- 1. The pinned unpkg URL must appear exactly once ---------------------
# One <script> include is expected; zero means the wrong generator/version,
# more than one means an unexpected duplicate reference.
PINNED_COUNT="$(grep -oF "$PINNED_URL" "$GRAPH_HTML" | wc -l || true)"
if [ "$PINNED_COUNT" -eq 0 ]; then
    die "Input does not reference the pinned vis-network URL:
  $PINNED_URL
Refusing to guess. Regenerate the graph with the pinned version, or update
PINNED_URL here (and the vendored asset + its hash) deliberately."
elif [ "$PINNED_COUNT" -ne 1 ]; then
    die "Expected exactly 1 occurrence of the pinned vis-network URL, found ${PINNED_COUNT}:
  $PINNED_URL
Refusing to rewrite an unexpected duplicate reference."
fi

# --- 2. Rewrite it to the vendored local asset ----------------------------
PINNED_URL_RE="$(printf '%s' "$PINNED_URL" | sed 's/[.[\*^$()+?{|]/\\&/g')"
sed "s#${PINNED_URL_RE}#${LOCAL_ASSET_PATH}#g" "$GRAPH_HTML" > "$TMP_DIR/index.html"

grep -qF "$PINNED_URL" "$TMP_DIR/index.html" && die "Pinned URL still present after rewrite"
grep -qF "$LOCAL_ASSET_PATH" "$TMP_DIR/index.html" || die "Rewrite failed: $LOCAL_ASSET_PATH not found in output"

# --- 3. No other external runtime references allowed -----------------------
# Runtime refs = things a browser would fetch or submit to: src/href/srcset/
# poster/action/formaction attributes (including later srcset candidates),
# CSS url(...) and @import, and meta refresh — pointing at http://, https://,
# or protocol-relative // URLs. Local absolute paths (single leading /, e.g.
# /assets/...) stay allowed. Plain-text URLs inside node data are not fetched
# (CSP blocks all external loads anyway) and are not rejected here.
# Keep these regexes in sync with the reconstruct step in
# .github/workflows/deploy-homelab.yml.
EXTERNAL_ATTR_RE="(src|href|srcset|poster|action|formaction)[[:space:]]*=[[:space:]]*[\"']?[[:space:]]*(https?:)?//"
EXTERNAL_SRCSET_RE="srcset[[:space:]]*=[[:space:]]*[\"'][^\"']*[,[:space:]][[:space:]]*(https?:)?//"
EXTERNAL_CSS_RE="url\([[:space:]]*[\"']?[[:space:]]*(https?:)?//|@import[[:space:]]+[\"']?[[:space:]]*(https?:)?//"
EXTERNAL_META_RE="<meta[^>]*url[[:space:]]*=[[:space:]]*[\"']?[[:space:]]*(https?:)?//"
EXTERNAL_REF_RE="$EXTERNAL_ATTR_RE|$EXTERNAL_SRCSET_RE|$EXTERNAL_CSS_RE|$EXTERNAL_META_RE"
if grep -Eqi "$EXTERNAL_REF_RE" "$TMP_DIR/index.html"; then
    echo "ERROR: transformed HTML still contains external runtime references:" >&2
    grep -Eni "$EXTERNAL_REF_RE" "$TMP_DIR/index.html" | cut -c1-200 | head -10 >&2
    exit 1
fi

# --- 4. Hash, gzip, base64 -------------------------------------------------
SHA256="$(sha256sum "$TMP_DIR/index.html" | awk '{print $1}')"
gzip -9 -n -c "$TMP_DIR/index.html" > "$TMP_DIR/index.html.gz"
base64 -w0 "$TMP_DIR/index.html.gz" > "$TMP_DIR/index.html.gz.b64"

HTML_BYTES=$(wc -c < "$TMP_DIR/index.html")
GZ_BYTES=$(wc -c < "$TMP_DIR/index.html.gz")
B64_BYTES=$(wc -c < "$TMP_DIR/index.html.gz.b64")

echo "Transformed HTML : ${HTML_BYTES} bytes"
echo "Gzipped          : ${GZ_BYTES} bytes"
echo "Base64 payload   : ${B64_BYTES} bytes"
echo "SHA-256 (HTML)   : ${SHA256}"

[ "$B64_BYTES" -le "$MAX_SECRET_BYTES" ] || \
    die "Base64 payload (${B64_BYTES} bytes) exceeds the ${MAX_SECRET_BYTES}-byte GitHub secret limit"

# --- 5. Update secrets via stdin (never echo values) -----------------------
echo "Updating secrets in ${REPO}..."
gh secret set "$SECRET_B64_NAME" --repo "$REPO" < "$TMP_DIR/index.html.gz.b64"
printf '%s' "$SHA256" | gh secret set "$SECRET_SHA_NAME" --repo "$REPO"

echo "Done. Trigger a deploy with (must target main — other refs never deploy):"
echo "  gh workflow run deploy-homelab.yml --repo ${REPO} --ref main -f service=project-graph"
