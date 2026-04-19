# Markdown Guardian for Claude Code

This repository contains a portable Claude Code subagent bundle that:

- checks generated Markdown files
- fixes common Markdown issues automatically

## What is included

- `.claude/agents/markdown-guardian.md`
  - reusable Claude Code subagent
- `.claude/hooks/auto-fix-markdown.ps1`
  - Windows automatic hook
- `.claude/hooks/auto-fix-markdown.sh`
  - automatic hook that runs after Markdown edits
- `.claude/reference/markdown-rules-summary.md`
  - compact rule summary derived from `Rules.md`
- `install-to-user-claude.ps1`
  - Windows installer
- `install-to-user-claude.sh`
  - Linux installer

## How it works

1. Claude Code writes or edits a file.
2. The user-level `PostToolUse` hook runs automatically.
3. If the changed file is `.md` or `.markdown`, the hook launches Claude Code
   again in headless mode with the `markdown-guardian` agent.
4. The agent reviews and fixes the Markdown file based on the bundled rule
   summary.

## Install on Windows

Run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install-to-user-claude.ps1
```

## Install on Linux

Run:

```bash
chmod +x ./install-to-user-claude.sh
./install-to-user-claude.sh
```

After that, the agent is available globally from your user profile and the hook
runs automatically in Claude Code sessions.

## Copy to another computer

Copy this whole folder and run the same installer there.

## Important note

Anthropic user accounts do not currently sync custom Claude Code subagents and
hooks automatically across computers. User-level scope (`~/.claude/...`) makes
them global on one machine, and this bundle makes them easy to copy to others.
