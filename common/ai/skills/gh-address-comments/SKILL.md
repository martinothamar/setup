---
name: gh-address-comments
description: Help address review/issue comments on the open GitHub PR for the current branch using gh CLI
metadata:
  short-description: Address comments in a GitHub PR review
---

# PR Comment Handler

Guide to find the open PR for the current branch and address its comments with gh CLI. Run all `gh` commands with elevated network access.

Assume `gh` is already authenticated with the required scopes for the target repository.

## 1) Inspect comments needing attention
- Run `python "<path-to-skill>/scripts/fetch_comments.py" --actionable` first.
- If you need outdated threads in the same list (for example to resolve them), add `--outdated`.
- For agent-friendly structured output, run `python "<path-to-skill>/scripts/fetch_comments.py" --json --actionable`.
- If bot noise is high, add `--bot-filter coderabbitai` (or other bot logins).
- If the script reports output was written to `/tmp/fetch_comments_*.md` or `.json`, read from that file instead of expecting inline output.

## 2) Ask the user for clarification
- Use the numbered actionable list from step 1.
- For any selected thread, inspect full, untruncated content with `python "<path-to-skill>/scripts/fetch_comments.py" --thread THREAD_ID`.
- Summarize required fixes and ask which numbered items to address.

## 3) If user chooses comments
- Apply fixes for the selected comments

## 4) Propose thread resolution — REQUIRE explicit user confirmation
After all fixes are applied, collect the IDs of the review threads that correspond to the addressed comments. Present the user with a numbered list, e.g.:

```
The following threads were addressed. Confirm which ones to mark as resolved:

  1. [THREAD_ID_A] path/to/file.ts:42 — "rename this variable"
  2. [THREAD_ID_B] path/to/other.ts:10 — "extract into helper"

Reply with the numbers to resolve (e.g. "1 2"), "all", or "none".
```

**Do not resolve any thread until the user explicitly confirms.** Once confirmed, resolve each selected thread by running:

```
python "<path-to-skill>/scripts/fetch_comments.py" --resolve THREAD_ID [THREAD_ID ...]
```

or, if the user confirms list indexes from the actionable output:

```
python "<path-to-skill>/scripts/fetch_comments.py" --resolve-indexes 1 2 3
```

If outdated threads were included in the actionable list, pass `--outdated` during resolution as well so indexes still match.

Notes:
- If `gh` commands fail with auth errors, report the failure and stop.
- Threads that are already `isResolved` should be excluded from the proposal list.
- Threads with `isOutdated` are excluded by default and can be included explicitly with `--outdated`.
