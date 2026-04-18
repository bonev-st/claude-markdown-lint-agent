# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A portable bundle that installs the `markdown-guardian` subagent and a
`PostToolUse` hook into the user-level Claude Code scope (`~/.claude/`). It is
not an application — there is no build, no tests, no package manifest. The
"product" is the contents of `.claude/` plus the two installers at the repo
root.

## Commands

Install the bundle into `~/.claude` on the current machine:

- Windows (PowerShell):
  ```powershell
  Set-ExecutionPolicy -Scope Process Bypass
  .\install-to-user-claude.ps1
  ```
- Linux/macOS:
  ```bash
  chmod +x ./install-to-user-claude.sh
  ./install-to-user-claude.sh
  ```

Both installers copy the agent, the platform-appropriate hook, and
`markdown-rules-summary.md` into `~/.claude/{agents,hooks,reference}`, then
merge a `PostToolUse` entry into `~/.claude/settings.json` matching
`Write|Edit|MultiEdit`. Re-running is idempotent — the installer skips the
hook entry if its `command` string already exists.

## Architecture

The pieces form a feedback loop around Markdown edits made by Claude Code:

1. `.claude/hooks/auto-fix-markdown.{sh,ps1}` — the `PostToolUse` hook. Reads
   the JSON tool payload from stdin, walks `tool_input` for any `.md` /
   `.markdown` paths (fields named `file_path`, `path`, `paths`, `file_paths`,
   plus recursive descent), and for each existing file re-invokes
   `claude -p ... --agent markdown-guardian --permission-mode acceptEdits`.
2. `.claude/agents/markdown-guardian.md` — the subagent definition (Sonnet,
   restricted to `Read, Edit, MultiEdit, Write, Glob, Grep`). It reads the
   rule summary and applies minimal, formatting-only fixes.
3. `.claude/reference/markdown-rules-summary.md` — the single source of truth
   for what "correct Markdown" means in this system. Both the hook prompt and
   the agent point at it. Keep the hook's inline bullet list and this file in
   sync when rules change.

Three invariants the loop relies on:

- **Recursion guard.** The hook checks `MARKDOWN_GUARDIAN_ACTIVE=1` and exits
  immediately if set, then sets it before invoking `claude`. Edits made by the
  nested Claude session therefore do not re-trigger the hook. Preserve this
  env-var gate in any hook change.
- **Self-edit exclusion.** Both hooks skip any resolved path containing
  `.claude/` so edits to the agent, rules, or hook itself don't trigger a
  guardian run.
- **Reference lookup order.** Hook and agent both prefer
  `~/.claude/reference/markdown-rules-summary.md` (user scope, installed) and
  fall back to the in-repo copy. When iterating locally on rules, edit the
  repo copy and re-run the installer — don't hand-edit the user-scope file.

## Editing conventions specific to this repo

- The two hook scripts (`auto-fix-markdown.sh` and `auto-fix-markdown.ps1`)
  are parallel implementations of the same contract. Changes to prompt text,
  path-walking logic, skipped directories, or the `--allowedTools` list must
  be mirrored in both.
- The two installers (`install-to-user-claude.sh` / `.ps1`) are likewise
  parallel — if you add a file under `.claude/`, add a copy step to both.
- The two uninstallers (`uninstall-from-user-claude.sh` / `.ps1`) must stay
  in lockstep with the installers: if the installer adds a file or changes
  the `PostToolUse` command string, the uninstaller must match. The command
  string used for idempotency and for removal is literally `$HOME`-prefixed
  (the shell expands it at runtime) — do not pre-expand it in the script.
- `.claude/settings.template.json` documents the exact hook-entry shape the
  installers write. If the installer's generated entry changes, update the
  template too.
- PowerShell compatibility: the hook runs under `shell: "powershell"`, which
  on Windows resolves to Windows PowerShell 5.1. `ConvertFrom-Json -Depth`
  was added in PS 6.2, so every use in `.ps1` files must be guarded by
  `if ($PSVersionTable.PSVersion.Major -ge 6)` — otherwise the hook and
  installer break on stock Windows 11.
- Markdown files in this repo (notably `README.md`) are themselves subject to
  the guardian when the hook is installed. The hook excludes `.claude/*`, so
  rule-summary edits are safe, but edits to `README.md` or this file will
  trigger a guardian pass.
