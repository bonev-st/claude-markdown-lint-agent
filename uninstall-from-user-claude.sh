#!/usr/bin/env bash

set -euo pipefail

user_claude_dir="${HOME}/.claude"
settings_path="${user_claude_dir}/settings.json"
hook_command='"$HOME/.claude/hooks/auto-fix-markdown.sh"'

rm -f "${user_claude_dir}/agents/markdown-guardian.md"
rm -f "${user_claude_dir}/hooks/auto-fix-markdown.sh"
rm -f "${user_claude_dir}/reference/markdown-rules-summary.md"
echo "Removed markdown-guardian agent, hook, and reference from ${user_claude_dir}."

if [[ ! -f "${settings_path}" ]]; then
  echo "No ${settings_path}; nothing further to do."
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "warning: python3 not found; leaving ${settings_path} untouched." >&2
  echo "         remove the PostToolUse hook entry with command ${hook_command} by hand."
  exit 0
fi

cp "${settings_path}" "${settings_path}.bak"

python3 - "${settings_path}" "${hook_command}" <<'PYEOF'
import json
import sys

settings_path, hook_command = sys.argv[1], sys.argv[2]

with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.get("hooks", {})
groups = hooks.get("PostToolUse", [])

new_groups = []
for group in groups:
    kept = [h for h in group.get("hooks", []) if h.get("command") != hook_command]
    if kept:
        g = dict(group)
        g["hooks"] = kept
        new_groups.append(g)

if new_groups:
    hooks["PostToolUse"] = new_groups
else:
    hooks.pop("PostToolUse", None)

if not hooks:
    settings.pop("hooks", None)

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF

echo "Updated ${settings_path} (backup at ${settings_path}.bak)."
