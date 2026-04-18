# Markdown Rules Summary

This file is derived from the user's `Rules.md` and is intended for the
`markdown-guardian` Claude Code subagent.

## Purpose

Fix generated Markdown so it is structurally valid, readable, and consistent
without changing the author's meaning.

## Core rules

1. Heading levels must increase by only one level at a time.
2. Use one consistent heading style in a document.
3. Leave blank lines around headings and tables when Markdown requires them.
4. Keep unordered list markers consistent at the same nesting level.
5. Use consistent list indentation. Prefer 2-space nested indentation.
6. Remove trailing spaces except where a hard line break is clearly intended.
7. Replace hard tabs with spaces unless preserving code is safer.
8. Fix reversed link syntax and clearly broken Markdown links.
9. Avoid multiple consecutive blank lines outside code blocks.
10. Prefer reasonably wrapped prose when a long line can be safely split.
11. Use a single space after `#` in ATX headings.
12. Keep fenced code blocks and surrounding blank lines consistent.
13. Keep table pipes and column counts consistent.
14. Ensure tables have blank lines around them when needed.
15. Prefer descriptive link text over vague labels like "here" or "click here"
    when the replacement is obvious from context.

## Editing policy

1. Preserve the original language of the file.
2. Preserve meaning, examples, commands, URLs, and code blocks.
3. Prefer the smallest safe edit.
4. If a rule is ambiguous or requires rewriting content, do not force it.
5. Correct formatting first; rewrite text only when required to fix clearly
   broken Markdown.
