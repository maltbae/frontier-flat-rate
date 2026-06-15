#!/bin/bash
# I/O Keynote Same-Day Push Script
# Usage: bash scripts/io-live-push.sh "commit message"
# Example: bash scripts/io-live-push.sh "I/O 2026 keynote live update 1415"
set -e
cd "$(git rev-parse --show-toplevel)" || exit 1
BRANCH=$(git branch --show-current)
if [ "$BRANCH" != "gh-pages" ]; then
  echo "ERROR: Not on gh-pages branch (on $BRANCH). Aborting."
  exit 1
fi
MSG="${1:-I/O live update $(date +%Y%m%d-%H%M)}"
git add -A
git commit -m "$MSG" --allow-empty
git push origin gh-pages
echo "✅ Pushed to gh-pages: $MSG"
# Verify endpoints
sleep 3
for path in "" "google-io-own-vs-rent.html" "gmail-5gb-own-vs-rent.html" "google-io-2026-live-analysis.html"; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://maltbae.github.io/frontier-flat-rate/blog/$path")
  echo "  /blog/$path → $CODE"
done
