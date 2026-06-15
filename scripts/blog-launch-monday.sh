#!/bin/bash
# Blog Launch Script — Monday May 19, 2026 9:00 AM ET
# ⚠️  THIS SCRIPT DEPLOYS TO PRODUCTION (GitHub Pages)
# Default: DRY-RUN (safe verification only)
# Use --live to actually push to production
# Usage: bash scripts/blog-launch-monday.sh [--live]

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LIVE_MODE="${1:-}"

cd "$REPO_DIR"

echo "=== Blog Launch Script ==="
echo "Repo: $REPO_DIR"
echo "Time: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "Mode: $([ "$LIVE_MODE" = "--live" ] && echo "🔴 LIVE DEPLOY" || echo "🟡 DRY-RUN (safe)")"

if [ "$LIVE_MODE" != "--live" ]; then
  echo ""
  echo "[DRY-RUN] Use --live flag to actually deploy."
  echo "[DRY-RUN] Running verification only..."
fi

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

# Check current branch
CURRENT=$(git branch --show-current)
echo "Current branch: $CURRENT"

# Sync gh-pages with main
MAIN_HEAD=$(git rev-parse main)
GHPAGES_HEAD=$(git rev-parse gh-pages 2>/dev/null || echo "none")
echo "main HEAD: $MAIN_HEAD"
echo "gh-pages HEAD: $GHPAGES_HEAD"

if [ "$MAIN_HEAD" != "$GHPAGES_HEAD" ]; then
  echo "⚠️  gh-pages behind main. Syncing..."
  git checkout gh-pages
  git merge main --ff-only
  git checkout "$CURRENT"
fi

# Check commits ahead
AHEAD=$(git rev-list --count origin/gh-pages..gh-pages 2>/dev/null || echo "0")
echo "Commits ahead of origin/gh-pages: $AHEAD"

if [ "$AHEAD" -eq 0 ]; then
  echo "⚠️ No commits ahead of origin. Checking if already live..."
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://maltbae.github.io/frontier-flat-rate/blog/)
  echo "Blog HTTP status: $HTTP_STATUS"
  if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Blog is already live!"
    exit 0
  fi
fi

# Show what will deploy
echo ""
echo "=== Commits to deploy ==="
git log --oneline origin/gh-pages..gh-pages 2>/dev/null || echo "(none)"
echo ""
echo "=== Files changed ==="
git diff --name-only origin/gh-pages..gh-pages 2>/dev/null || echo "(none)"

# DRY-RUN: Stop here unless --live
if [ "$LIVE_MODE" != "--live" ]; then
  echo ""
  echo "[DRY-RUN] ✅ Verification complete. No changes pushed."
  echo "[DRY-RUN] To deploy: bash scripts/blog-launch-monday.sh --live"
  exit 0
fi

# LIVE: Verify no dirty files
DIRTY=$(git status --porcelain | wc -l | tr -d ' ')
if [ "$DIRTY" -gt 0 ]; then
  echo "WARNING: $DIRTY uncommitted changes. Stashing..."
  git stash
fi

# Push gh-pages (deployment branch)
echo ""
echo "🔴 Pushing gh-pages (DEPLOYMENT)..."
git push origin gh-pages
echo "Pushing main (source)..."
git push origin main

# Verify deployment
echo "Waiting 30s for GitHub Pages build..."
sleep 30
echo "Verifying blog is live..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://maltbae.github.io/frontier-flat-rate/blog/)
if [ "$HTTP_STATUS" = "200" ]; then
  echo "✅ Blog LIVE! HTTP 200 confirmed."
else
  echo "⚠️ Blog returned HTTP $HTTP_STATUS. May need a few more minutes."
fi

echo ""
echo "✅ Blog pushed! Live at: https://maltbae.github.io/frontier-flat-rate/blog/"
echo ""
echo "Post-publish checklist:"
echo "  1. Verify https://maltbae.github.io/frontier-flat-rate/blog/ loads"
echo "  2. Check both blog post links work"
echo "  3. Verify Open Graph preview (share debugger)"
echo "  4. Post #3 template ready for same-day Google I/O content (May 19 1PM ET)"
