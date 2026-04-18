# Markdown Guardian for Claude Code

A portable bundle that installs a Claude Code subagent plus a `PostToolUse`
hook into your user-level Claude Code scope (`~/.claude/`). After install,
whenever Claude Code writes or edits a `.md` / `.markdown` file, the hook
spawns a nested Claude Code session running the `markdown-guardian` agent,
which checks and fixes the file against a shared rule summary.

## What is included

- `.claude/agents/markdown-guardian.md` — the reusable subagent definition.
- `.claude/hooks/auto-fix-markdown.sh` — `PostToolUse` hook for bash
  (Linux, macOS, Git Bash, WSL).
- `.claude/hooks/auto-fix-markdown.ps1` — `PostToolUse` hook for PowerShell
  (Windows).
- `.claude/reference/markdown-rules-summary.md` — the rule summary both the
  hook prompt and the agent read. This is the single place to edit the rules.
- `.claude/settings.template.json` — reference shape of the `PostToolUse`
  entry the installers write into `~/.claude/settings.json` (informational).
- `install-to-user-claude.{sh,ps1}` — platform-specific installers.
- `uninstall-from-user-claude.{sh,ps1}` — platform-specific uninstallers.

## How it works

1. Claude Code writes or edits a file using `Write`, `Edit`, or `MultiEdit`.
2. The user-level `PostToolUse` hook fires. It reads the tool payload from
   stdin, walks it for `.md` / `.markdown` paths, and for each one:
3. Re-invokes `claude -p ... --agent markdown-guardian --permission-mode acceptEdits`
   with an `MARKDOWN_GUARDIAN_ACTIVE=1` guard so the nested session's own
   edits do not re-trigger the hook.
4. The agent reads `markdown-rules-summary.md` and applies minimal,
   formatting-only fixes to the target file.

Paths inside any `.claude/` directory are skipped, so the agent, rules, and
hook never rewrite themselves.

## Requirements

- **Claude Code CLI** installed and reachable on `PATH` (`claude --version`).
- **Linux / macOS / WSL / Git Bash:** `bash` and `python3` (the hook and
  installer both use Python 3 for JSON handling).
- **Windows:** Windows PowerShell 5.1+ (bundled with Windows 11) or
  PowerShell 7+.

## Install on Windows

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install-to-user-claude.ps1
```

## Install on Linux / macOS

```bash
chmod +x ./install-to-user-claude.sh
./install-to-user-claude.sh
```

Both installers:

- copy the agent, hook, and rule summary into `~/.claude/`,
- back up an existing `~/.claude/settings.json` to `settings.json.bak`,
- merge a `PostToolUse` entry matching `Write|Edit|MultiEdit` (idempotent —
  re-running does not duplicate the entry).

## Verify the installation

Start Claude Code in a scratch directory and create or edit a `.md` file.
You should see the status line `markdown-guardian: checking Markdown files`
while the hook runs, and the file will be normalised per the rules.

You can also inspect the state directly:

- `~/.claude/agents/markdown-guardian.md` exists.
- `~/.claude/hooks/auto-fix-markdown.{sh,ps1}` exists.
- `~/.claude/settings.json` contains a `hooks.PostToolUse` entry whose
  `matcher` is `Write|Edit|MultiEdit` and whose `command` points at the
  hook script.

## Customize the rules

Edit `.claude/reference/markdown-rules-summary.md` in this repo, then re-run
the installer. The agent reads `~/.claude/reference/markdown-rules-summary.md`
first and falls back to the in-repo copy, so propagating a rule change
requires a reinstall on every machine.

## Temporarily disable

Set `MARKDOWN_GUARDIAN_ACTIVE=1` in the environment of your Claude Code
session. The hook exits immediately when this variable is set — that is also
how the nested session avoids re-triggering itself.

## Uninstall

Windows:

```powershell
.\uninstall-from-user-claude.ps1
```

Linux / macOS:

```bash
chmod +x ./uninstall-from-user-claude.sh
./uninstall-from-user-claude.sh
```

The uninstallers remove the three installed files and delete the matching
`PostToolUse` entry from `~/.claude/settings.json`, leaving any other hooks
untouched. A backup of `settings.json` is written alongside the original.

## Troubleshooting

- **`python3: command not found` (bash hook)** — install Python 3. The bash
  hook uses it to parse the tool payload.
- **`claude: command not found` (inside the hook)** — Claude Code is not on
  the `PATH` visible to the hook. Reinstall Claude Code or adjust your
  shell startup files.
- **`markdown-guardian failed for <path>`** — something failed in the nested
  session. Check that `~/.claude/agents/markdown-guardian.md` exists and
  that `--agent markdown-guardian` resolves when you run `claude` directly.
- **Hook appears to do nothing on Windows PowerShell 5.1** — upgrade to
  PowerShell 7 or verify the hook runs without `-Depth 100` errors in the
  PS 5.1 code path (this has been patched, but reinstall if you pulled an
  older version).

## Cost and latency

Every `.md` / `.markdown` edit triggers a nested Claude Code session (up to
a 300 s timeout). That adds per-edit latency and API usage. If you bulk-edit
many Markdown files, expect both to add up. Set
`MARKDOWN_GUARDIAN_ACTIVE=1` for the duration of a bulk operation if you
want to skip the hook.

## Copy to another computer

Copy this whole folder and run the matching installer there.

## Important note

Anthropic user accounts do not currently sync custom Claude Code subagents
and hooks automatically across computers. User-level scope (`~/.claude/...`)
makes them global on one machine, and this bundle makes them easy to copy
to others.
