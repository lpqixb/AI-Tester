#!/usr/bin/env python3
"""Save short-drama markdown as YYYYMMDDHHmmss.md (Asia/Shanghai)."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

SHANGHAI_TZ = timezone(timedelta(hours=8))
DEFAULT_OUTPUT_DIR = "short-drama"


def now_shanghai() -> datetime:
    return datetime.now(SHANGHAI_TZ)


def timestamp_filename() -> str:
    return now_shanghai().strftime("%Y%m%d%H%M%S") + ".md"


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Save short-drama markdown to short-drama/YYYYMMDDHHmmss.md"
    )
    parser.add_argument(
        "--input",
        "-i",
        default="-",
        help="Markdown file path (default: stdin)",
    )
    parser.add_argument(
        "--output-dir",
        "-o",
        default=DEFAULT_OUTPUT_DIR,
        help=f"Output directory (default: {DEFAULT_OUTPUT_DIR})",
    )
    return parser.parse_args(argv)


def read_markdown(path: str) -> str:
    if path == "-":
        return sys.stdin.read()
    return Path(path).read_text(encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    try:
        content = read_markdown(args.input)
    except OSError as exc:
        print(json.dumps({"error": str(exc)}), file=sys.stderr)
        return 2

    if not content.strip():
        print(json.dumps({"error": "Empty markdown content"}), file=sys.stderr)
        return 2

    # Ensure trailing newline
    if not content.endswith("\n"):
        content += "\n"

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    filename = timestamp_filename()
    output_path = output_dir / filename
    output_path.write_text(content, encoding="utf-8")

    result = {
        "savedPath": str(output_path.resolve()),
        "filename": filename,
        "savedAt": now_shanghai().isoformat(timespec="seconds"),
        "bytes": output_path.stat().st_size,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
