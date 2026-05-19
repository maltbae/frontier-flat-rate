#!/bin/bash
# Blog Post-Push Verification Script (SI #60)
# Run 90+ seconds after git push origin gh-pages
set -euo pipefail

BASE="https://maltbae.github.io/frontier-flat-rate"
PASSED=0
FAILED=0

check_url() {
  local url="$1" label="$2" expected="${3:-200}"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
  if [ "$code" = "$expected" ]; then
    echo "✅ $label: $code"
    ((PASSED++)) || true
  else
    echo "❌ $label: $code (expected $expected)"
    ((FAILED++)) || true
  fi
}

echo "=== Blog Live Verification — $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo ""

# HTTP status checks
check_url "$BASE/" "Main site" 200
check_url "$BASE/blog/" "Blog index" 200
check_url "$BASE/blog/google-io-own-vs-rent.html" "Post 1 (Google I/O)" 200
check_url "$BASE/blog/gmail-5gb-own-vs-rent.html" "Post 2 (Gmail 5GB)" 200
check_url "$BASE/blog/google-io-2026-live-analysis.html" "Post 3 (Live Analysis)" 200
check_url "$BASE/blog/style.css" "Blog CSS" 200

echo ""

# Content size checks
for page in "blog/index.html" "blog/google-io-own-vs-rent.html" "blog/gmail-5gb-own-vs-rent.html" "blog/google-io-2026-live-analysis.html"; do
  size=$(curl -s "$BASE/$page" 2>/dev/null | wc -c | tr -d ' ')
  if [ "$size" -gt 1000 ]; then
    echo "✅ $page: ${size} bytes"
    ((PASSED++)) || true
  else
    echo "❌ $page: ${size} bytes (too small)"
    ((FAILED++)) || true
  fi
done

echo ""

# OG tag checks
og_title=$(curl -s "$BASE/blog/google-io-own-vs-rent.html" 2>/dev/null | grep -c 'og:title' || echo "0")
og_image=$(curl -s "$BASE/blog/google-io-own-vs-rent.html" 2>/dev/null | grep -c 'og:image' || echo "0")
jsonld=$(curl -s "$BASE/blog/google-io-own-vs-rent.html" 2>/dev/null | grep -c 'application/ld+json' || echo "0")

[ "$og_title" -gt 0 ] && { echo "✅ OG title present"; ((PASSED++)) || true; } || { echo "❌ OG title missing"; ((FAILED++)) || true; }
[ "$og_image" -gt 0 ] && { echo "✅ OG image present"; ((PASSED++)) || true; } || { echo "❌ OG image missing"; ((FAILED++)) || true; }
[ "$jsonld" -gt 0 ] && { echo "✅ JSON-LD present"; ((PASSED++)) || true; } || { echo "❌ JSON-LD missing"; ((FAILED++)) || true; }

echo ""

# Content hash checks (SI #68 — verify committed content is actually served)
echo "--- Content Verification ---"
for check in "sessionStorage:Analytics tracker:blog/index.html" "canonical:Canonical URL:blog/google-io-own-vs-rent.html" "canonical:Canonical URL:blog/gmail-5gb-own-vs-rent.html"; do
  needle="${check%%:*}"
  label="${check#*:}"; label="${label%%:*}"
  page="${check##*:}"
  count=$(curl -s "$BASE/$page" 2>/dev/null | grep -c "$needle" || echo "0")
  if [ "$count" -gt 0 ]; then
    echo "✅ $label present in $page"
    ((PASSED++)) || true
  else
    echo "⚠️  $label NOT found in $page (may need rebuild time)"
    ((FAILED++)) || true
  fi
done

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
[ "$FAILED" -eq 0 ] && echo "🟢 BLOG IS LIVE AND HEALTHY" || echo "🔴 ISSUES DETECTED — investigate"
