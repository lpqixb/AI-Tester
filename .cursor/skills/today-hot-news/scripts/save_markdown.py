#!/usr/bin/env python3
"""Render hot news JSON to markdown and save as YYYYMMDDHHmmss.md (Asia/Shanghai)."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Any

SHANGHAI_TZ = timezone(timedelta(hours=8))
DEFAULT_OUTPUT_DIR = "hot-news"


def now_shanghai() -> datetime:
    return datetime.now(SHANGHAI_TZ)


def timestamp_filename() -> str:
    return now_shanghai().strftime("%Y%m%d%H%M%S") + ".md"


def format_display_time(iso_time: str) -> str:
    if not iso_time:
        return now_shanghai().strftime("%Y-%m-%d %H:%M")
    try:
        dt = datetime.fromisoformat(iso_time)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=SHANGHAI_TZ)
        return dt.astimezone(SHANGHAI_TZ).strftime("%Y-%m-%d %H:%M")
    except ValueError:
        return iso_time


def format_item(index: int, item: dict[str, str]) -> str:
    title = item.get("title", "").strip()
    link = item.get("link", "").strip()
    source = item.get("source", "").strip()

    if link and source:
        return f"{index}. {title} — [{source}]({link})"
    if link:
        return f"{index}. [{title}]({link})"
    if source:
        return f"{index}. {title} — {source}"
    return f"{index}. {title}"


def format_international_item(index: int, item: dict[str, str]) -> str:
    title = item.get("title", "").strip()
    title_zh = item.get("titleZh", item.get("title_zh", "")).strip()
    link = item.get("link", "").strip()
    source = item.get("source", "").strip()

    if title_zh and title_zh != title:
        headline = title_zh
        if link and source:
            line = f"{index}. {headline} — [{source}]({link})"
        elif link:
            line = f"{index}. [{headline}]({link})"
        elif source:
            line = f"{index}. {headline} — {source}"
        else:
            line = f"{index}. {headline}"
        return f"{line}\n   > 原文：{title}"

    return format_item(index, item)


def format_baidu_item(index: int, title: str) -> str:
    return f"{index}. {title.strip()}"


def render_markdown(data: dict[str, Any], baidu_titles: list[str] | None = None) -> str:
    fetched_at = data.get("fetchedAt", "")
    display_time = format_display_time(fetched_at)
    date_label = now_shanghai().strftime("%Y-%m-%d")
    sections = data.get("sections", {})
    errors = data.get("errors", [])

    lines: list[str] = [
        f"# 今日热点新闻（{date_label}）",
        "",
        f"> 抓取时间：{display_time} (Asia/Shanghai)",
        "",
    ]

    if baidu_titles:
        lines.extend(["## 国内热搜（百度）", ""])
        for i, title in enumerate(baidu_titles, 1):
            if title.strip():
                lines.append(format_baidu_item(i, title))
        lines.append("")

    domestic_items = sections.get("domestic", {}).get("items", [])
    if domestic_items:
        lines.extend(["## 国内要闻", ""])
        for i, item in enumerate(domestic_items, 1):
            lines.append(format_item(i, item))
        lines.append("")

    international_items = sections.get("international", {}).get("items", [])
    if international_items:
        lines.extend(["## 国际要闻", ""])
        for i, item in enumerate(international_items, 1):
            lines.append(format_international_item(i, item))
        lines.append("")

    tech_items = sections.get("tech", {}).get("items", [])
    if tech_items:
        lines.extend(["## 科技热点", ""])
        for i, item in enumerate(tech_items, 1):
            lines.append(format_item(i, item))
        lines.append("")

    sources_note = "百度热搜、Google 新闻、Hacker News、IT之家"
    if errors:
        sources_note += f" | 部分源失败：{'; '.join(errors)}"

    lines.extend(
        [
            "---",
            f"数据来源：{sources_note} | 保存时间：{display_time} (Asia/Shanghai)",
            "",
            "以上内容来自公开信息汇总，仅供参考。",
            "",
        ]
    )

    return "\n".join(lines)


def load_json(path: str | None) -> dict[str, Any]:
    if path and path != "-":
        text = Path(path).read_text(encoding="utf-8")
    else:
        text = sys.stdin.read()
    return json.loads(text)


def load_baidu_titles(path: str | None) -> list[str]:
    if not path:
        return []
    text = Path(path).read_text(encoding="utf-8")
    data = json.loads(text)
    if isinstance(data, list):
        return [str(t) for t in data if str(t).strip()]
    if isinstance(data, dict) and "titles" in data:
        return [str(t) for t in data["titles"] if str(t).strip()]
    raise ValueError("Baidu titles JSON must be an array or {\"titles\": [...]}")


def load_intl_translations(path: str) -> list[str] | dict[str, str]:
    text = Path(path).read_text(encoding="utf-8")
    data = json.loads(text)
    if isinstance(data, list):
        return [str(t) for t in data]
    if isinstance(data, dict):
        if "translations" in data:
            return [str(t) for t in data["translations"]]
        return {str(k): str(v) for k, v in data.items()}
    raise ValueError(
        "International translations JSON must be an array, "
        '{"translations": [...]}, or {"English title": "中文翻译"}'
    )


def apply_intl_translations(
    data: dict[str, Any], translations: list[str] | dict[str, str]
) -> dict[str, Any]:
    """Attach titleZh to international items from parallel array or title-keyed map."""
    sections = data.get("sections", {})
    international = sections.get("international", {})
    items = international.get("items", [])
    if not items:
        return data

    if isinstance(translations, dict):
        for item in items:
            title = item.get("title", "").strip()
            zh = translations.get(title, "").strip()
            if zh:
                item["titleZh"] = zh
        return data

    for item, zh in zip(items, translations):
        zh = str(zh).strip()
        if zh:
            item["titleZh"] = zh
    return data


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Save hot news as YYYYMMDDHHmmss.md")
    parser.add_argument(
        "--input",
        "-i",
        default="-",
        help="News JSON file from fetch_hot_news.py (default: stdin)",
    )
    parser.add_argument(
        "--baidu",
        help="Optional JSON file with Baidu hot search titles (array or {\"titles\": [...]})",
    )
    parser.add_argument(
        "--intl-translations",
        help=(
            "Optional Chinese translations for international items: "
            "parallel array (same order), {\"translations\": [...]}, "
            "or {\"English title\": \"中文标题\"}"
        ),
    )
    parser.add_argument(
        "--output-dir",
        "-o",
        default=DEFAULT_OUTPUT_DIR,
        help=f"Directory to save markdown files (default: {DEFAULT_OUTPUT_DIR})",
    )
    parser.add_argument(
        "--stdout",
        action="store_true",
        help="Also print markdown to stdout",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    try:
        data = load_json(args.input)
        baidu_titles = load_baidu_titles(args.baidu)
        if args.intl_translations:
            translations = load_intl_translations(args.intl_translations)
            apply_intl_translations(data, translations)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(json.dumps({"error": str(exc)}), file=sys.stderr)
        return 2

    markdown = render_markdown(data, baidu_titles or None)

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    filename = timestamp_filename()
    output_path = output_dir / filename
    output_path.write_text(markdown, encoding="utf-8")

    result = {
        "savedPath": str(output_path.resolve()),
        "filename": filename,
        "fetchedAt": data.get("fetchedAt", ""),
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))

    if args.stdout:
        print(markdown)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
