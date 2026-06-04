#!/usr/bin/env bash
# blog-index-integrity.sh — Automated blog index integrity checker
# Prevents KL#913 (Index-Autonomy Gap) from recurring
# Compares HTML files on disk in blog/ against links in blog/index.html
#
# Usage:
#   ./scripts/blog-index-integrity.sh          # Check only (dry run)
#   ./scripts/blog-index-integrity.sh --fix    # Show fix guidance
#
# Exit codes: 0 = clean, 1 = orphans found, 2 = broken links found

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BLOG_DIR="$REPO_DIR/blog"
INDEX_FILE="$BLOG_DIR/index.html"
FIX_MODE=false

[[ "${1:-}" == "--fix" ]] && FIX_MODE=true

echo "📋 Blog Index Integrity Check"
echo "   Repository: $REPO_DIR"
echo "   Index: blog/index.html"
echo "   Mode: $(${FIX_MODE} && echo 'FIX' || echo 'DRY-RUN')"
echo ""

if [[ ! -f "$INDEX_FILE" ]]; then
    echo "❌ ERROR: blog/index.html not found at $INDEX_FILE"
    exit 2
fi

# --- Files on disk (blog/ directory only) ---
FILES_ON_DISK=$(ls -1 "$BLOG_DIR"/*.html 2>/dev/null \
    | xargs -n1 basename \
    | grep -v '^index\.html$' \
    | grep -v '\.template$' \
    | sort)

DISK_COUNT=$(echo "$FILES_ON_DISK" | grep -c . || true)

# --- Links in index.html ---
# Extract all hrefs pointing to .html files
# Separate into blog-local vs external (../)
ALL_LINKS=$(grep -o 'href="[^"]*\.html"' "$INDEX_FILE" \
    | sed 's/href="//;s/"//' \
    | sort -u)

LOCAL_LINKS=$(echo "$ALL_LINKS" | grep -v '^\.\./' | grep -v '^http' | grep -v '^#' || true)
EXTERNAL_LINKS=$(echo "$ALL_LINKS" | grep '^\.\./' | sed 's|^\.\./||' || true)

LOCAL_COUNT=$(echo "$LOCAL_LINKS" | grep -c . || true)

# --- Orphans (on disk, not in index) ---
ORPHANS=$(comm -23 <(echo "$FILES_ON_DISK") <(echo "$LOCAL_LINKS") || true)
ORPHAN_COUNT=$(echo "$ORPHANS" | grep -c . || true)

# --- Broken local links (in index, no file on disk) ---
BROKEN_LOCAL=$(comm -13 <(echo "$FILES_ON_DISK") <(echo "$LOCAL_LINKS") || true)
BROKEN_LOCAL_COUNT=$(echo "$BROKEN_LOCAL" | grep -c . || true)

# --- Broken external links (../ links where file doesn't exist) ---
BROKEN_EXTERNAL=""
if [[ -n "$EXTERNAL_LINKS" ]]; then
    for link in $EXTERNAL_LINKS; do
        if [[ ! -f "$REPO_DIR/$link" ]]; then
            BROKEN_EXTERNAL="$BROKEN_EXTERNAL ../$link"
        fi
    done
fi
BROKEN_EXTERNAL=$(echo "$BROKEN_EXTERNAL" | sed 's/^ *//' | sort || true)
BROKEN_EXTERNAL_COUNT=$(echo "$BROKEN_EXTERNAL" | grep -c . || true)

echo "   Blog files on disk: $DISK_COUNT"
echo "   Local links in index: $LOCAL_COUNT"
echo "   Orphans (not indexed): $ORPHAN_COUNT"
echo "   Broken local links: $BROKEN_LOCAL_COUNT"
echo "   Broken external links: $BROKEN_EXTERNAL_COUNT"
echo ""

EXIT_CODE=0

# Report orphans — PRIMARY check for KL#913
if [[ $ORPHAN_COUNT -gt 0 ]]; then
    echo "⚠️  ORPHANED POSTS (live but unreachable from index):"
    echo "$ORPHANS" | while read -r f; do
        [[ -n "$f" ]] && echo "   $f"
    done
    echo ""

    if $FIX_MODE; then
        echo "🔧 FIX GUIDANCE:"
        echo "$ORPHANS" | while read -r orphan; do
            [[ -z "$orphan" ]] && continue
            TITLE=$(grep -o '<title>[^<]*</title>' "$BLOG_DIR/$orphan" 2>/dev/null | sed 's/<[^>]*>//g' || echo "$orphan")
            echo "   ADD to index: $orphan — \"$TITLE\""
        done
        echo ""
        echo "   After fixing:"
        echo "     git add blog/index.html"
        echo "     git commit -m 'fix: add orphaned posts to blog index'"
    fi
    EXIT_CODE=1
fi

# Report broken local links
if [[ $BROKEN_LOCAL_COUNT -gt 0 ]]; then
    echo "❌ BROKEN LOCAL LINKS (in index, no file in blog/):"
    echo "$BROKEN_LOCAL" | while read -r l; do
        [[ -n "$l" ]] && echo "   $l"
    done
    echo ""
    EXIT_CODE=2
fi

# Report broken external links
if [[ $BROKEN_EXTERNAL_COUNT -gt 0 ]]; then
    echo "❌ BROKEN EXTERNAL LINKS (../ references, no file in repo root):"
    echo "$BROKEN_EXTERNAL" | while read -r l; do
        [[ -n "$l" ]] && echo "   $l"
    done
    echo ""
    [[ $EXIT_CODE -lt 2 ]] && EXIT_CODE=2
fi

if [[ $EXIT_CODE -eq 0 ]]; then
    echo "✅ Blog index integrity: CLEAN ($DISK_COUNT posts, zero drift)"
fi

exit $EXIT_CODE
