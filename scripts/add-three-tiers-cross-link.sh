#!/bin/bash
# add-three-tiers-cross-link.sh — Add "Three Tiers of AI Access" cross-link to Related Posts
# For each HTML file in blog/ that has a <section class="related-posts"><ul> block
# and does NOT already link to three-tiers-of-ai-access-mythos.html,
# insert a new <li> entry before the closing </ul></section>.

set -euo pipefail

BLOG_DIR="/Users/BAE/frontier-flat-rate/blog"
TARGET="three-tiers-of-ai-access-mythos.html"
NEW_LI="  <li><a href=\"/blog/${TARGET}\">The Three Tiers of AI Access: Own, Rent, and Mythos</a> — Anthropic's Claude Mythos (NSA, 150+ orgs, cyberweapon-grade) reveals the real three-tier model. Most developers are stuck in the middle: renting subsidized AI that can be repriced, throttled, or locked at any moment.</li>"

count_done=0
count_skip=0
count_err=0

for html in "$BLOG_DIR"/*.html; do
  base=$(basename "$html")
  [[ "$base" == "index.html" ]] && continue
  [[ "$base" == "$TARGET" ]] && continue

  if grep -q "$TARGET" "$html" 2>/dev/null; then
    count_skip=$((count_skip+1))
    continue
  fi

  # Find Related Posts section and the last </ul> that closes it
  # Use python for safer multiline replacement
  if python3 -c "
import sys, re
p = sys.argv[1]
target = sys.argv[2]
new_li = sys.argv[3]
with open(p) as f:
    content = f.read()
if target in content:
    sys.exit(0)
# Find Related Posts section's closing </ul> just before </section>
# Match: <section class=\"related-posts\">...</section>
m = re.search(r'(<section class=\"related-posts\">.*?)(\n</ul>\n</section>)', content, re.DOTALL)
if not m:
    sys.exit(2)
# Insert new_li right before the </ul>
new_content = content[:m.end(1)] + '\n' + new_li + content[m.end(1):]
with open(p, 'w') as f:
    f.write(new_content)
sys.exit(0)
" "$html" "$TARGET" "$NEW_LI"; then
    count_done=$((count_done+1))
    echo "ADDED: $base"
  else
    count_err=$((count_err+1))
    echo "ERR (no related-posts section): $base"
  fi
done

echo ""
echo "=== Summary ==="
echo "Added:  $count_done"
echo "Skipped (already linked): $count_skip"
echo "Errors (no section found): $count_err"
