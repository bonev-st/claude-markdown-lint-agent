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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
extractor="${script_dir}/lib/extract-markdown-paths.py"

if [[ ! -f "${extractor}" ]]; then
  echo "markdown-guardian: extractor missing at ${extractor}" >&2
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

mapfile -t markdown_paths < <(printf '%s' "${raw_input}" | python3 "${extractor}")

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

Read the rule summary at "${reference_path}" and apply only the safe,
formatting-only fixes it lists. Preserve meaning, code samples, links, and
the original language. If the file is already acceptable, leave it unchanged.
Return only a short summary that names the rule-summary version you applied.
EOF
)

  if ! MARKDOWN_GUARDIAN_ACTIVE=1 claude \
    -p "${prompt}" \
    --agent markdown-guardian \
    --permission-mode acceptEdits >/dev/null; then
    echo "markdown-guardian failed for ${resolved}" >&2
  fi
done

exit 0
