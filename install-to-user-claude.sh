#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_claude_dir="${repo_root}/.claude"
user_claude_dir="${HOME}/.claude"

mkdir -p \
  "${user_claude_dir}/agents" \
  "${user_claude_dir}/hooks" \
  "${user_claude_dir}/reference"

cp "${source_claude_dir}/agents/markdown-guardian.md" \
  "${user_claude_dir}/agents/markdown-guardian.md"
cp "${source_claude_dir}/hooks/auto-fix-markdown.sh" \
  "${user_claude_dir}/hooks/auto-fix-markdown.sh"
cp "${source_claude_dir}/reference/markdown-rules-summary.md" \
  "${user_claude_dir}/reference/markdown-rules-summary.md"

chmod +x "${user_claude_dir}/hooks/auto-fix-markdown.sh"

settings_path="${user_claude_dir}/settings.json"

if [[ -f "${settings_path}" ]]; then
  settings_json="$(cat "${settings_path}")"
else
  settings_json='{}'
fi

updated_json="$(
  python3 -c '
import json
import sys

hook_command = "\"$HOME/.claude/hooks/auto-fix-markdown.sh\""

try:
    settings = json.loads(sys.stdin.read() or "{}")
except Exception:
    settings = {}

hooks = settings.setdefault("hooks", {})
post_tool_use = hooks.setdefault("PostToolUse", [])

already_exists = False
for group in post_tool_use:
    for hook in group.get("hooks", []):
        if hook.get("command") == hook_command:
            already_exists = True

if not already_exists:
    post_tool_use.append({
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
            {
                "type": "command",
                "shell": "bash",
                "command": hook_command,
                "timeout": 300,
                "statusMessage": "markdown-guardian: checking Markdown files"
            }
        ]
    })

print(json.dumps(settings, indent=2))
' <<< "${settings_json}"
)"

printf '%s\n' "${updated_json}" > "${settings_path}"

echo "Installed markdown-guardian to ${user_claude_dir}"
echo "Agent: ${HOME}/.claude/agents/markdown-guardian.md"
echo "Hook : ${HOME}/.claude/hooks/auto-fix-markdown.sh"
echo "Settings updated: ${settings_path}"
