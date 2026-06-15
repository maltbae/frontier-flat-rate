#!/bin/bash
# generate-sitemap.sh — Auto-generate sitemap.xml from blog/*.html
# Fixes KL#913-class sitemap drift and domain errors
# Usage: bash scripts/generate-sitemap.sh [--apply]
#   --apply  Overwrites sitemap.xml (default: dry-run)

set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SITEMAP="$REPO_DIR/sitemap.xml"
DOMAIN="https://maltbae.github.io/frontier-flat-rate"
TODAY=$(date +%Y-%m-%d)
APPLY=false
[[ "${1:-}" == "--apply" ]] && APPLY=true

# Collect blog posts (exclude index.html, rss.xml, atom.xml)
cd "$REPO_DIR"
POSTS=()
for f in blog/*.html; do
  base=$(basename "$f")
  [[ "$base" == "index.html" || "$base" == "rss.xml" || "$base" == "atom.xml" ]] && continue
  POSTS+=("$base")
done

echo "Found ${#POSTS[@]} blog posts"

# Build sitemap
{
  cat <<'HEADER'
<?xml version="1.0" encoding="UTF-8"?>
<ns0:urlset xmlns:ns0="http://www.sitemaps.org/schemas/sitemap/0.9">
HEADER

  # Root page
  echo "  <ns0:url><ns0:loc>${DOMAIN}/</ns0:loc><ns0:changefreq>weekly</ns0:changefreq><ns0:priority>1.0</ns0:priority></ns0:url>"

  # Copilot migration page
  if [[ -f "copilot-migration.html" ]]; then
    echo "  <ns0:url><ns0:loc>${DOMAIN}/copilot-migration.html</ns0:loc><ns0:changefreq>monthly</ns0:changefreq><ns0:priority>0.9</ns0:priority></ns0:url>"
  fi

  # Blog index
  echo "  <ns0:url><ns0:loc>${DOMAIN}/blog/</ns0:loc><ns0:changefreq>daily</ns0:changefreq><ns0:priority>0.9</ns0:priority></ns0:url>"

  # Blog posts (sorted by filename for stability)
  for post in $(printf '%s\n' "${POSTS[@]}" | sort); do
    echo "  <ns0:url><ns0:loc>${DOMAIN}/blog/${post}</ns0:loc><ns0:lastmod>${TODAY}</ns0:lastmod><ns0:changefreq>monthly</ns0:changefreq><ns0:priority>0.8</ns0:priority></ns0:url>"
  done

  # RSS + Atom
  echo "  <ns0:url><ns0:loc>${DOMAIN}/blog/rss.xml</ns0:loc><ns0:changefreq>daily</ns0:changefreq><ns0:priority>0.5</ns0:priority></ns0:url>"
  echo "  <ns0:url><ns0:loc>${DOMAIN}/blog/atom.xml</ns0:loc><ns0:changefreq>daily</ns0:changefreq><ns0:priority>0.5</ns0:priority></ns0:url>"

  echo "</ns0:urlset>"
} > /tmp/sitemap-new.xml

# Compare
if diff -q "$SITEMAP" /tmp/sitemap-new.xml > /dev/null 2>&1; then
  echo "✅ Sitemap already correct (${#POSTS[@]} posts)"
  exit 0
fi

echo "⚠️  Sitemap drift detected:"
diff "$SITEMAP" /tmp/sitemap-new.xml | head -20

if $APPLY; then
  cp /tmp/sitemap-new.xml "$SITEMAP"
  echo "✅ Sitemap regenerated with ${#POSTS[@]} posts + feeds"
else
  echo "💡 Run with --apply to fix"
fi
