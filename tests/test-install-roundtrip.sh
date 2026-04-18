#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
installer="${repo_root}/install-to-user-claude.sh"
uninstaller="${repo_root}/uninstall-from-user-claude.sh"
hook_command='"$HOME/.claude/hooks/auto-fix-markdown.sh"'

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to run these tests" >&2
  exit 1
fi

pass=0
fail=0

check() {
  local msg="$1"
  shift
  if "$@"; then
    echo "    PASS ${msg}"
    pass=$((pass + 1))
  else
    echo "    FAIL ${msg}"
    fail=$((fail + 1))
  fi
}

hook_entry_count() {
  python3 - "$1" "${hook_command}" <<'PYEOF'
import json, sys
try:
    with open(sys.argv[1]) as f:
        s = json.load(f)
except FileNotFoundError:
    print(0); sys.exit(0)
count = 0
for g in s.get("hooks", {}).get("PostToolUse", []):
    for h in g.get("hooks", []):
        if h.get("command") == sys.argv[2]:
            count += 1
print(count)
PYEOF
}

json_key_exists() {
  python3 - "$1" "$2" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
node = s
for part in sys.argv[2].split("."):
    if isinstance(node, dict) and part in node:
        node = node[part]
    else:
        sys.exit(1)
sys.exit(0)
PYEOF
}

make_tmp_home() {
  mktemp -d "${TMPDIR:-/tmp}/md-guardian-roundtrip-XXXXXX"
}

run_installer_ok() {
  HOME="$1" bash "${installer}" >/dev/null 2>&1
}

run_installer_expect_fail() {
  ! HOME="$1" bash "${installer}" >/dev/null 2>&1
}

run_uninstaller_ok() {
  HOME="$1" bash "${uninstaller}" >/dev/null 2>&1
}

echo "Scenario: fresh install -> re-install -> uninstall"
tmp="$(make_tmp_home)"
run_installer_ok "${tmp}"
check "agent file installed" test -f "${tmp}/.claude/agents/markdown-guardian.md"
check "hook file installed" test -f "${tmp}/.claude/hooks/auto-fix-markdown.sh"
check "extractor installed" test -f "${tmp}/.claude/hooks/lib/extract-markdown-paths.py"
check "reference installed" test -f "${tmp}/.claude/reference/markdown-rules-summary.md"
check "settings.json created" test -f "${tmp}/.claude/settings.json"
check "one hook entry" test "$(hook_entry_count "${tmp}/.claude/settings.json")" = 1

run_installer_ok "${tmp}"
check "re-install stays idempotent (still 1 entry)" test "$(hook_entry_count "${tmp}/.claude/settings.json")" = 1

run_uninstaller_ok "${tmp}"
check "agent removed" test ! -e "${tmp}/.claude/agents/markdown-guardian.md"
check "hook removed" test ! -e "${tmp}/.claude/hooks/auto-fix-markdown.sh"
check "extractor removed" test ! -e "${tmp}/.claude/hooks/lib/extract-markdown-paths.py"
check "reference removed" test ! -e "${tmp}/.claude/reference/markdown-rules-summary.md"
check "zero hook entries after uninstall" test "$(hook_entry_count "${tmp}/.claude/settings.json")" = 0
rm -rf "${tmp}"

echo "Scenario: install preserves unrelated settings"
tmp="$(make_tmp_home)"
mkdir -p "${tmp}/.claude"
cat > "${tmp}/.claude/settings.json" <<'JSON'
{
  "permissions": {
    "allow": ["Bash(ls:*)"]
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "shell": "bash", "command": "echo preexisting"}
        ]
      }
    ]
  }
}
JSON

run_installer_ok "${tmp}"
check "preexisting permissions survive" json_key_exists "${tmp}/.claude/settings.json" "permissions.allow"
check "our entry added (now 1)" test "$(hook_entry_count "${tmp}/.claude/settings.json")" = 1
check "preexisting hook entry still present" bash -c "python3 -c 'import json,sys
s=json.load(open(sys.argv[1]))
for g in s[\"hooks\"][\"PostToolUse\"]:
  for h in g[\"hooks\"]:
    if h.get(\"command\") == \"echo preexisting\":
      sys.exit(0)
sys.exit(1)' '${tmp}/.claude/settings.json'"

run_uninstaller_ok "${tmp}"
check "our entry removed after uninstall" test "$(hook_entry_count "${tmp}/.claude/settings.json")" = 0
check "preexisting permissions still survive" json_key_exists "${tmp}/.claude/settings.json" "permissions.allow"
check "preexisting hook entry still present after uninstall" bash -c "python3 -c 'import json,sys
s=json.load(open(sys.argv[1]))
for g in s[\"hooks\"][\"PostToolUse\"]:
  for h in g[\"hooks\"]:
    if h.get(\"command\") == \"echo preexisting\":
      sys.exit(0)
sys.exit(1)' '${tmp}/.claude/settings.json'"
rm -rf "${tmp}"

echo "Scenario: malformed settings.json is not overwritten"
tmp="$(make_tmp_home)"
mkdir -p "${tmp}/.claude"
echo '{ this is not valid json' > "${tmp}/.claude/settings.json"
original_hash="$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "${tmp}/.claude/settings.json")"

check "installer exits non-zero on bad JSON" run_installer_expect_fail "${tmp}"
check "settings.json is byte-for-byte unchanged" test "$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "${tmp}/.claude/settings.json")" = "${original_hash}"
check "backup was created" test -f "${tmp}/.claude/settings.json.bak"
rm -rf "${tmp}"

echo ""
echo "${pass} passed, ${fail} failed"
if [[ "${fail}" -gt 0 ]]; then
  exit 1
fi
