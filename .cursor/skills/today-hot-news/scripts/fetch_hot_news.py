#!/usr/bin/env python3
"""Fetch today's hot news from public RSS feeds (no API keys, stdlib only)."""

from __future__ import annotations

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone, timedelta
from email.utils import parsedate_to_datetime
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

TIMEOUT_SECONDS = 15
USER_AGENT = "today-hot-news-skill/1.0 (+https://cursor.com/docs/skills)"

RSS_SOURCES: dict[str, dict[str, str]] = {
    "google_cn": {
        "section": "domestic",
        "name": "Google 新闻（中文）",
        "url": "https://news.google.com/rss?hl=zh-CN&gl=CN&ceid=CN:zh-Hans",
    },
    "google_us": {
        "section": "international",
        "name": "Google 新闻（英文）",
        "url": "https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en",
    },
    "hn": {
        "section": "tech",
        "name": "Hacker News",
        "url": "https://hnrss.org/frontpage",
    },
    "ithome": {
        "section": "tech",
        "name": "IT之家",
        "url": "https://www.ithome.com/rss/",
    },
}

SECTION_ORDER = ("domestic", "international", "tech")


def fetch_url(url: str) -> bytes:
    request = Request(url, headers={"User-Agent": USER_AGENT})
    with urlopen(request, timeout=TIMEOUT_SECONDS) as response:
        return response.read()


def strip_cdata(text: str | None) -> str:
    if not text:
        return ""
    text = text.strip()
    if text.startswith("<![CDATA[") and text.endswith("]]>"):
        return text[9:-3].strip()
    return text


def child_text(element: ET.Element, tag: str) -> str:
    child = element.find(tag)
    if child is None or child.text is None:
        return ""
    return strip_cdata(child.text)


def parse_pub_date(raw: str) -> str:
    raw = raw.strip()
    if not raw:
        return ""
    try:
        dt = parsedate_to_datetime(raw)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.isoformat()
    except (TypeError, ValueError, OverflowError):
        return raw


def split_google_title(title: str) -> tuple[str, str]:
    """Split 'Headline - Publisher' into (headline, publisher)."""
    if " - " in title:
        headline, publisher = title.rsplit(" - ", 1)
        return headline.strip(), publisher.strip()
    return title.strip(), ""


def parse_rss_items(xml_bytes: bytes, limit: int, source_id: str) -> list[dict[str, str]]:
    root = ET.fromstring(xml_bytes)
    channel = root.find("channel")
    if channel is None:
        channel = root

    items: list[dict[str, str]] = []
    for item in channel.findall("item"):
        if len(items) >= limit:
            break

        title = child_text(item, "title")
        link = child_text(item, "link")
        pub_date = parse_pub_date(child_text(item, "pubDate"))
        source = child_text(item, "source")

        if source_id.startswith("google_"):
            title, publisher = split_google_title(title)
            if not source and publisher:
                source = publisher

        if not title:
            continue

        items.append(
            {
                "title": title,
                "link": link,
                "source": source or RSS_SOURCES[source_id]["name"],
                "pubDate": pub_date,
            }
        )

    return items


def now_shanghai_iso() -> str:
    tz = timezone(timedelta(hours=8))
    return datetime.now(tz).isoformat(timespec="seconds")


def build_sections(
    selected_sections: set[str] | None,
    limit: int,
    errors: list[str],
) -> dict[str, Any]:
    section_items: dict[str, list[dict[str, str]]] = {
        "domestic": [],
        "international": [],
        "tech": [],
    }
    section_meta: dict[str, Any] = {}

    for source_id, meta in RSS_SOURCES.items():
        section = meta["section"]
        if selected_sections and section not in selected_sections:
            continue

        try:
            xml_bytes = fetch_url(meta["url"])
            parsed = parse_rss_items(xml_bytes, limit, source_id)
        except (HTTPError, URLError, ET.ParseError, TimeoutError, OSError) as exc:
            errors.append(f"{source_id}: {exc}")
            continue

        if section == "tech":
            section_items["tech"].extend(parsed)
            sources = section_meta.get("tech", {}).get("sources", [])
            if meta["name"] not in sources:
                sources.append(meta["name"])
            section_meta["tech"] = {"sources": sources}
        else:
            section_items[section] = parsed
            section_meta[section] = {"source": meta["name"]}

    # Trim tech to limit * number of tech feeds (rough cap: 2x limit)
    if section_items["tech"]:
        section_items["tech"] = section_items["tech"][: limit * 2]

    result: dict[str, Any] = {}
    for section in SECTION_ORDER:
        if selected_sections and section not in selected_sections:
            continue
        result[section] = {
            "items": section_items.get(section, []),
            **section_meta.get(section, {}),
        }

    return result


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fetch hot news from public RSS feeds.")
    parser.add_argument(
        "--limit",
        type=int,
        default=10,
        help="Max items per RSS source (default: 10)",
    )
    parser.add_argument(
        "--sections",
        type=str,
        default="",
        help="Comma-separated sections: domestic,international,tech",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    limit = max(1, args.limit)

    selected: set[str] | None = None
    if args.sections.strip():
        selected = {s.strip() for s in args.sections.split(",") if s.strip()}
        invalid = selected - set(SECTION_ORDER)
        if invalid:
            print(json.dumps({"error": f"Unknown sections: {', '.join(sorted(invalid))}"}), file=sys.stderr)
            return 2

    errors: list[str] = []
    sections = build_sections(selected, limit, errors)

    payload = {
        "fetchedAt": now_shanghai_iso(),
        "sections": sections,
        "errors": errors,
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if any(sec.get("items") for sec in sections.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
