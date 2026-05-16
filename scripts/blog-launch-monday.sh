#!/bin/bash
# Blog Launch Script — Monday May 19, 2026 9:00 AM ET
# Pushes staged blog content to GitHub Pages (goes live on push)
# Prerequisites: blog/ directory with index.html + 2 posts committed
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

echo "=== Blog Launch Script ==="
echo "Repo: $REPO_DIR"
echo "Time: $(date -u '+%Y-%m-%d %H:%M UTC')"

# Verify blog directory exists
if [ ! -d "blog" ]; then
  echo "ERROR: blog/ directory not found!"
  exit 1
fi

# Verify key files
for f in blog/index.html blog/style.css blog/google-io-own-vs-rent.html blog/gmail-5gb-own-vs-rent.html; do
  if [ ! -f "$f" ]; then
    echo "ERROR: Missing $f"
    exit 1
  fi
done
echo "✅ All blog files verified"

# Check commits ahead
AHEAD=$(git rev-list --count @{upstream}..HEAD 2>/dev/null || echo "0")
echo "Commits ahead of origin: $AHEAD"

if [ "$AHEAD" -eq 0 ]; then
  echo "WARNING: No commits ahead of origin. Blog may already be live."
fi

# Verify no dirty files
DIRTY=$(git status --porcelain | wc -l | tr -d ' ')
if [ "$DIRTY" -gt 0 ]; then
  echo "WARNING: $DIRTY uncommitted changes. Stashing..."
  git stash
fi

# Push to origin
echo "Pushing to origin/main..."
git push origin main

echo "✅ Blog pushed! Live at: https://maltbae.github.io/frontier-flat-rate/blog/"
echo ""
echo "Post-publish checklist:"
echo "  1. Verify https://maltbae.github.io/frontier-flat-rate/blog/ loads"
echo "  2. Check both blog post links work"
echo "  3. Verify Open Graph preview (share debugger)"
echo "  4. Post #3 template ready for same-day Google I/O content (May 19 1PM ET)"
