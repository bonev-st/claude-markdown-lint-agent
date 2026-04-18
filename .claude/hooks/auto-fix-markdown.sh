#!/usr/bin/env bash

set -euo pipefail

if [[ "${MARKDOWN_GUARDIAN_ACTIVE:-}" == "1" ]]; then
  exit 0
fi

raw_input="$(cat)"
if [[ -z "${raw_input//[[:space:]]/}" ]]; then
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "markdown-guardian: python3 is required for JSON parsing" >&2
  exit 0
fi

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
user_reference_path="${HOME}/.claude/reference/markdown-rules-summary.md"
project_reference_path="${project_dir}/.claude/reference/markdown-rules-summary.md"

if [[ -f "${user_reference_path}" ]]; then
  reference_path="${user_reference_path}"
else
  reference_path="${project_reference_path}"
fi

mapfile -t markdown_paths < <(
  python3 -c '
import json
import os
import sys

try:
    payload = json.load(sys.stdin)
except Exception:
    sys.exit(0)

seen = set()

def add_candidate(value):
    if not isinstance(value, str):
        return
    trimmed = value.strip()
    if trimmed.lower().endswith((".md", ".markdown")) and trimmed not in seen:
        seen.add(trimmed)
        print(trimmed)

def walk(node):
    if node is None:
        return
    if isinstance(node, str):
        add_candidate(node)
        return
    if isinstance(node, list):
        for item in node:
            walk(item)
        return
    if isinstance(node, dict):
        for key, value in node.items():
            if key in {"file_path", "path", "paths", "file_paths"}:
                walk(value)
            elif not isinstance(value, (str, int, float, bool)):
                walk(value)

walk(payload.get("tool_input"))
' <<< "${raw_input}"
)

if [[ "${#markdown_paths[@]}" -eq 0 ]]; then
  exit 0
fi

for path in "${markdown_paths[@]}"; do
  if [[ "${path}" = /* ]]; then
    full_path="${path}"
  else
    full_path="${project_dir}/${path}"
  fi

  if [[ ! -f "${full_path}" ]]; then
    continue
  fi

  resolved="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "${full_path}")"

  case "${resolved}" in
    */.claude/*) continue ;;
  esac

  prompt=$(cat <<EOF
Review and correct the Markdown file at "${resolved}".

First read the rule summary at "${reference_path}".

Apply only safe Markdown fixes:
- heading hierarchy and blank lines
- list indentation and list marker consistency
- trailing whitespace, tabs, and excessive blank lines
- fenced code block spacing when safe
- table formatting and surrounding blank lines
- link syntax and descriptive link text when obvious

Do not add new content. Preserve meaning, code samples, links, and the original language.
If the file is already acceptable, leave it unchanged.
Return only a short summary.
EOF
)

  if ! MARKDOWN_GUARDIAN_ACTIVE=1 claude \
    -p "${prompt}" \
    --agent markdown-guardian \
    --permission-mode acceptEdits \
    --allowedTools "Read,Edit,MultiEdit,Write,Glob,Grep" >/dev/null; then
    echo "markdown-guardian failed for ${resolved}" >&2
  fi
done

exit 0
