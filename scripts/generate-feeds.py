#!/usr/bin/env python3
"""Generate RSS 2.0 and Atom 1.0 feeds from blog HTML files.

Reads all .html files (except index.html) from blog/, extracts metadata
from <title>, <meta name="description">, and JSON-LD, then writes
rss.xml and atom.xml sorted by date (newest first).

Usage:
  python3 scripts/generate-feeds.py          # generate to blog/
  python3 scripts/generate-feeds.py --check   # check coverage only
"""

import glob
import json
import os
import re
import sys
from html import unescape
from pathlib import Path
from xml.sax.saxutils import escape

BLOG_DIR = Path(__file__).resolve().parent.parent / "blog"
BASE_URL = "https://maltbae.github.io/frontier-flat-rate/blog"
SITE_TITLE = "Frontier at Flat Rate"
SITE_DESC = "Own your AI agent. Stop renting it. Proof points, analysis, and the economics of self-hosted vs. subscription AI."

RFC1123_FMT = "%a, %d %b %Y %H:%M:%S +0000"
ATOM_FMT = "%Y-%m-%dT%H:%M:%S+00:00"


def extract_metadata(html_path: Path) -> dict | None:
    """Extract title, description, date from a blog HTML file."""
    try:
        content = html_path.read_text(encoding="utf-8")
    except Exception:
        return None

    # Title
    title_match = re.search(r"<title>([^<]+)</title>", content)
    raw_title = unescape(title_match.group(1)) if title_match else html_path.stem
    # Strip site suffix
    title = re.sub(r"\s*[—–-]\s*Frontier at Flat Rate\s*$", "", raw_title).strip()

    # Description
    desc_match = re.search(r'name="description"\s+content="([^"]*)"', content)
    description = unescape(desc_match.group(1)) if desc_match else title

    # Date from JSON-LD or file
    date = None
    ld_match = re.search(r'<script type="application/ld\+json">\s*(.*?)\s*</script>', content, re.DOTALL)
    if ld_match:
        try:
            ld = json.loads(ld_match.group(1))
            date = ld.get("datePublished") or ld.get("dateCreated")
        except (json.JSONDecodeError, AttributeError):
            pass

    if not date:
        # Try meta date
        meta_date = re.search(r'name="date"\s+content="([^"]*)"', content)
        if meta_date:
            date = meta_date.group(1)

    slug = html_path.stem
    url = f"{BASE_URL}/{slug}.html"

    return {
        "title": title,
        "description": description,
        "date": date or "2026-01-01",
        "url": url,
        "slug": slug,
    }


def generate_rss(posts: list[dict]) -> str:
    """Generate RSS 2.0 XML."""
    items = []
    for p in posts:
        pub_date = p["date"]
        if "T" in pub_date:
            from datetime import datetime
            try:
                dt = datetime.fromisoformat(pub_date.replace("Z", "+00:00"))
                pub_date = dt.strftime(RFC1123_FMT)
            except Exception:
                pass
        items.append(
            f"""    <item>
      <title>{escape(p['title'])}</title>
      <link>{escape(p['url'])}</link>
      <description>{escape(p['description'])}</description>
      <pubDate>{escape(pub_date)}</pubDate>
      <guid isPermaLink="true">{escape(p['url'])}</guid>
    </item>"""
        )

    return f"""<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>{escape(SITE_TITLE)}</title>
    <link>{BASE_URL}</link>
    <description>{escape(SITE_DESC)}</description>
    <language>en-us</language>
    <atom:link href="{BASE_URL}/rss.xml" rel="self" type="application/rss+xml"/>
    <lastBuildDate>{escape(posts[0]['date'] if posts else '')}</lastBuildDate>
{chr(10).join(items)}
  </channel>
</rss>
"""


def generate_atom(posts: list[dict]) -> str:
    """Generate Atom 1.0 XML."""
    entries = []
    for p in posts:
        updated = p["date"]
        if not ("T" in updated and ("+" in updated or "Z" in updated)):
            updated = f"{updated}T00:00:00+00:00"
        entries.append(
            f"""  <entry>
    <title>{escape(p['title'])}</title>
    <link href="{escape(p['url'])}"/>
    <updated>{escape(updated)}</updated>
    <id>{escape(p['url'])}</id>
    <summary>{escape(p['description'])}</summary>
  </entry>"""
        )

    return f"""<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>{escape(SITE_TITLE)}</title>
  <link href="{BASE_URL}"/>
  <link href="{BASE_URL}/atom.xml" rel="self"/>
  <id>{BASE_URL}/atom.xml</id>
  <updated>{escape(posts[0]['date'] + 'T00:00:00+00:00' if posts else '')}</updated>
  <subtitle>{escape(SITE_DESC)}</subtitle>
{chr(10).join(entries)}
</feed>
"""


def main():
    html_files = sorted(BLOG_DIR.glob("*.html"))
    html_files = [f for f in html_files if f.name != "index.html"]

    posts = []
    for f in html_files:
        meta = extract_metadata(f)
        if meta:
            posts.append(meta)

    # Sort by date, newest first
    posts.sort(key=lambda p: p["date"], reverse=True)

    print(f"Found {len(html_files)} HTML files, extracted {len(posts)} posts")

    if len(posts) != len(html_files):
        extracted_slugs = {p["slug"] for p in posts}
        for f in html_files:
            if f.stem not in extracted_slugs:
                print(f"  WARNING: could not extract metadata from {f.name}")

    if "--check" in sys.argv:
        print(f"Feed coverage: {len(posts)}/{len(html_files)}")
        if len(posts) < len(html_files):
            print("ACTION: regenerate feeds to include missing posts")
            sys.exit(1)
        print("OK: all posts covered")
        sys.exit(0)

    rss_path = BLOG_DIR / "rss.xml"
    atom_path = BLOG_DIR / "atom.xml"

    rss_content = generate_rss(posts)
    atom_content = generate_atom(posts)

    rss_path.write_text(rss_content, encoding="utf-8")
    atom_path.write_text(atom_content, encoding="utf-8")

    print(f"Wrote {rss_path} ({len(posts)} items)")
    print(f"Wrote {atom_path} ({len(posts)} entries)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
