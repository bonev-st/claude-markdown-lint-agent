# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A portable bundle that installs the `markdown-guardian` subagent and a
`PostToolUse` hook into the user-level Claude Code scope (`~/.claude/`). It is
not an application — there is no build. The "product" is the contents of
`.claude/` plus the installer / uninstaller pairs at the repo root.

## Commands

Install the bundle into `~/.claude` on the current machine:

- Windows (PowerShell):
  ```powershell
  Set-ExecutionPolicy -Scope Process Bypass
  .\install-to-user-claude.ps1
  ```
- Linux / macOS:
  ```bash
  chmod +x ./install-to-user-claude.sh
  ./install-to-user-claude.sh
  ```

Uninstall:

- Windows: `.\uninstall-from-user-claude.ps1`
- Linux / macOS: `./uninstall-from-user-claude.sh`

Run the extractor tests (both should print `N passed, 0 failed`):

```bash
bash tests/test-walker.sh
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\test-walker.ps1
```

## Architecture

The pieces form a feedback loop around Markdown edits made by Claude Code:

1. `.claude/hooks/auto-fix-markdown.{sh,ps1}` — the `PostToolUse` hook. It
   reads the JSON tool payload from stdin and forwards it to the extractor
   below. For each returned path that exists and is not under a `.claude/`
   directory, the hook re-invokes
   `claude -p ... --agent markdown-guardian --permission-mode acceptEdits`.
2. `.claude/hooks/lib/extract-markdown-paths.{py,ps1}` — pure function:
   stdin/file-path JSON → newline-separated `.md` / `.markdown` paths to
   stdout. Silent on malformed input. The Python and PowerShell versions
   implement the same contract and are exercised by the tests under
   `tests/`.
3. `.claude/agents/markdown-guardian.md` — the subagent definition (Sonnet,
   restricted to `Read, Edit, MultiEdit, Glob, Grep` — deliberately no
   `Write` so it can only fix existing files). It reads the rule summary
   and applies minimal, formatting-only fixes.
4. `.claude/reference/markdown-rules-summary.md` — the single source of
   truth for what "correct Markdown" means. Has a `version:` field; the
   agent reports which version it applied in its output.

Five invariants the loop relies on:

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
- **Single source of truth for agent tools.** The agent's `tools:`
  frontmatter is authoritative. The hook does not pass `--allowedTools`, so
  widening or narrowing the agent's capabilities is a one-file change.
  Keep it that way: do not add `--allowedTools` to the hook invocation.
- **Rule-summary versioning.** Bump `version:` in
  `markdown-rules-summary.md` whenever a rule is added, removed, or
  materially changed. The agent is instructed to name the version it
  applied in its summary output, so mixed-version machines are detectable.

## Editing conventions specific to this repo

- The two hook scripts are parallel implementations of the same contract.
  Changes to prompt text, path-walking logic (via the extractor), or
  skipped directories must be mirrored in both.
- The two extractors are likewise parallel. Any change to the set of
  recognised payload keys or extension filters must be applied in both
  `extract-markdown-paths.py` and `extract-markdown-paths.ps1`, and a new
  fixture added under `tests/hook-payloads/` exercising the change.
- The two installers (`install-to-user-claude.{sh,ps1}`) are parallel — if
  you add a file under `.claude/`, add a copy step to both and a
  corresponding removal step to both uninstallers.
- The uninstaller's hook-command string used for the `PostToolUse` removal
  match is literally `$HOME`-prefixed (the shell expands it at runtime).
  Do not pre-expand it, or the match will fail and the old entry will
  linger in `settings.json`.
- **PowerShell compatibility.** The hook runs under `shell: "powershell"`,
  which on Windows resolves to Windows PowerShell 5.1. `ConvertFrom-Json
  -Depth` was added in PS 6.2, so every use in `.ps1` files must be
  guarded by `if ($PSVersionTable.PSVersion.Major -ge 6)` — otherwise the
  hook, installer, uninstaller, or extractor breaks on stock Windows 11.
- **StrictMode pitfalls.** The `.ps1` files set `Set-StrictMode -Version
  Latest`. Accessing a missing property with `$obj.foo` throws. When
  reading JSON-derived objects, check property existence via
  `$obj.PSObject.Properties` iteration (see `Get-Property` helper in the
  extractor) rather than `$obj.foo -ne $null`.
- Markdown files in this repo (notably `README.md`) are themselves subject
  to the guardian when the hook is installed. The hook excludes
  `.claude/*`, so rule-summary edits are safe, but edits to `README.md`
  or this file will trigger a guardian pass.
