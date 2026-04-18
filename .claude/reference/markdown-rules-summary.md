---
version: 2
---

# Markdown Rules Summary

This file is derived from the user's `Rules.md` (the markdownlint rule
reference, MD001–MD060) and is intended for the `markdown-guardian`
Claude Code subagent. The `version:` field above is the authoritative
rule-summary version; bump it whenever the rules below change so agents
can report which version they applied.

## Purpose

Fix generated Markdown so it is structurally valid, readable, and
consistent without changing the author's meaning. The rule IDs below
correspond to markdownlint rules in `Rules.md`.

Rules are grouped into three classes:

- **Auto-fix** — apply when the fix is unambiguous and formatting-only.
- **Flag only** — report in the output summary but leave the file
  unchanged; the fix requires judgment, domain knowledge, or content
  rewriting.
- **Not enforced** — ignore unless the project explicitly configures
  them.

## Auto-fix

### Headings

- **MD003** Heading style. Normalize every heading to the style of the
  first heading in the document (`atx`, `atx_closed`, or `setext`).
- **MD018** No space after `#` in ATX headings (`#Heading` →
  `# Heading`).
- **MD019** Collapse multiple spaces after `#` in ATX headings
  (`##  Heading` → `## Heading`).
- **MD020** Ensure single-space padding inside closed ATX headings
  (`#Heading#` → `# Heading #`).
- **MD021** Collapse multiple spaces inside closed ATX headings.
- **MD022** Surround headings with one blank line above and below.
- **MD023** Headings must start at column 0. Remove leading spaces,
  except inside a blockquote (where `> # Heading` is correct).
- **MD026** Strip trailing punctuation (`.,;:!` plus the full-width
  equivalents `。，；：！`) from headings. Do not strip `?`.

### Lists

- **MD004** Unordered list marker style. Normalize every unordered list
  marker in the document to the first one used (`*`, `-`, or `+`).
- **MD005** Fix inconsistent indentation between items at the same list
  level.
- **MD007** Indent nested unordered lists by 2 spaces per level.
- **MD030** Use exactly one space between a list marker (`*`, `-`, `+`,
  `1.`) and the item text.
- **MD032** Surround lists with one blank line above and below (except
  at the very start or end of the file).

### Whitespace and line endings

- **MD009** Remove trailing whitespace. Preserve an exact 2-space
  trailing sequence when it is clearly used as a hard line break.
- **MD010** Replace hard tab characters with spaces **outside** code
  blocks. Do not touch tabs inside fenced or indented code blocks
  (languages such as Makefile or Go are tab-sensitive).
- **MD012** Collapse runs of more than one consecutive blank line to a
  single blank line (does not apply inside code blocks).
- **MD047** Ensure the file ends with exactly one trailing newline
  character.

### Blockquotes

- **MD027** Collapse multiple spaces after `>` in blockquotes to one.
- **MD028** Do not leave a bare blank line between two `>` blocks. If
  the author intended one continuous quote, put `>` on the empty line.
  If they are clearly separate quotes, insert non-quote text between
  them or leave the file alone and flag it.

### Code blocks

- **MD031** Surround fenced code blocks with one blank line above and
  below.
- **MD046** Keep a single code-block style (fenced or indented) per
  document, matching the first block used.
- **MD048** Keep a single fence style per document (`` ``` `` or `~~~`),
  matching the first fence used.

### Links, images, and emphasis

- **MD011** Reversed link syntax: `(text)[url]` → `[text](url)`.
- **MD034** Wrap bare URLs and email addresses in angle brackets:
  `https://x` → `<https://x>`, `a@b` → `<a@b>`. Do not modify URLs
  already inside `[text](url)` or inside code spans.
- **MD035** Horizontal rule style. Normalize every `---` / `***` /
  `___` / `* * *` / `- - -` line to the first style used.
- **MD037** Remove spaces immediately inside emphasis markers
  (`** bold **` → `**bold**`). Applies to `*`, `_`, `**`, `__`.
- **MD038** Remove unnecessary spaces inside code spans
  (`` ` code ` `` → `` `code` ``). Preserve a single leading or
  trailing space when the content itself begins or ends with a backtick
  (`` `` ` backticks ` `` ``).
- **MD039** Remove spaces immediately inside link text
  (`[ text ](url)` → `[text](url)`).
- **MD049** Keep one emphasis style per document (`*` or `_`).
- **MD050** Keep one strong style per document (`**` or `__`).
- **MD053** Remove reference definitions that are not referenced by any
  link or image. Preserve comment-style definitions matching
  `[//]: # ...`.
- **MD054** Link / image style. When a link or image can be converted
  to `inline` style without information loss, convert it. Do not
  invent new reference definitions or move existing ones.

### Tables

- **MD055** Table pipe style. Normalize every table to the leading /
  trailing pipe pattern of the first table in the document.
- **MD056** Every row in a table must have the same cell count as the
  header. Pad short rows with empty cells; never truncate overfull
  rows — flag those instead.
- **MD058** Surround tables with one blank line above and below.
- **MD060** Keep a consistent column-padding style per document
  (`aligned`, `compact`, or `tight`), matching the first table.

## Flag only

These rules are reported in the output summary but the file is left
unchanged because the fix requires judgment, domain knowledge, or
content rewriting.

- **MD001** Skipped heading levels (e.g. `#` followed by `###`).
  Promoting or demoting may change the document's outline.
- **MD013** Line length (default >80). Do not reflow prose — authors
  often break lines deliberately.
- **MD014** Shell commands prefixed with `$` without showing output.
- **MD024** Duplicate heading text. Renaming may break incoming
  anchors.
- **MD025** Multiple top-level (H1) headings. Which to keep is
  authorial.
- **MD029** Ordered list prefix style (`1. 2. 3.` vs `1. 1. 1.`).
  Re-numbering can change cross-references.
- **MD033** Inline HTML. Often intentional (e.g. `<br>`, `<details>`,
  centered images).
- **MD036** Emphasized line used as a heading. Cannot tell from style
  alone whether the author meant a heading.
- **MD040** Fenced code block without a language tag. Cannot infer the
  language safely.
- **MD041** First line of the file is not a top-level heading.
  Inventing a title is authorial.
- **MD042** Empty links (`[text]()`, `[text](#)`). A real target is
  required.
- **MD043** Required heading structure. Project-specific.
- **MD044** Proper-name capitalization. Project-specific configuration.
- **MD045** Image without alt text. Writing meaningful alt text
  requires understanding the image.
- **MD051** Invalid link fragment (e.g. `#missing-heading`). May be a
  typo or a removed heading.
- **MD052** Reference link with an undefined label. Adding the
  definition requires knowing the target URL.
- **MD059** Non-descriptive link text (`click here`, `here`, `link`,
  `more`). Rewriting needs surrounding context.

## Editing policy

1. Preserve the original language of the file.
2. Preserve meaning, facts, examples, commands, URLs, and code blocks
   exactly.
3. Do not modify content inside fenced or indented code blocks, except
   where a rule explicitly allows it (currently only MD010 tabs
   **outside** code blocks).
4. Prefer the smallest safe edit. If a rule is ambiguous or requires
   rewriting prose, leave it alone and report it under "flagged".
5. Fix formatting first; rewrite text only when required to make the
   Markdown parse correctly.
6. When you finish, report in your summary:
   - the rule-summary `version:` you applied,
   - the rule IDs you fixed,
   - the rule IDs you flagged without fixing.
