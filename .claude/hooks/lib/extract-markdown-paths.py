#!/usr/bin/env python3
"""Extract .md / .markdown file paths from a Claude Code hook JSON payload.

Reads JSON from stdin (or from a file path given as the first argument) and
prints one candidate path per line to stdout. Silent on malformed input.

Used by auto-fix-markdown.sh and by the tests under tests/.
"""

import json
import sys

PATH_KEYS = {"file_path", "path", "paths", "file_paths"}


def add_candidate(value, seen):
    if not isinstance(value, str):
        return
    trimmed = value.strip()
    if trimmed.lower().endswith((".md", ".markdown")) and trimmed not in seen:
        seen.add(trimmed)
        print(trimmed)


def walk(node, seen):
    if node is None:
        return
    if isinstance(node, str):
        add_candidate(node, seen)
        return
    if isinstance(node, list):
        for item in node:
            walk(item, seen)
        return
    if isinstance(node, dict):
        for key, value in node.items():
            if key in PATH_KEYS:
                walk(value, seen)
            elif not isinstance(value, (str, int, float, bool)):
                walk(value, seen)


def main():
    if len(sys.argv) > 1:
        with open(sys.argv[1]) as f:
            raw = f.read()
    else:
        raw = sys.stdin.read()

    try:
        payload = json.loads(raw) if raw.strip() else {}
    except Exception:
        sys.exit(0)

    seen = set()
    walk(payload.get("tool_input"), seen)


if __name__ == "__main__":
    main()
