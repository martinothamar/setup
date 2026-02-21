---
name: gh-address-comments
description: Help address review/issue comments on the open GitHub PR for the current branch using gh CLI; verify gh auth first and prompt the user to authenticate if not logged in.
metadata:
  short-description: Address comments in a GitHub PR review
---

# PR Comment Handler

Guide to find the open PR for the current branch and address its comments with gh CLI. Run all `gh` commands with elevated network access.

Prereq: ensure `gh` is authenticated (for example, run `gh auth login` once), then run `gh auth status` with escalated permissions (include workflow/repo scopes) so `gh` commands succeed. If sandboxing blocks `gh auth status`, rerun it with `sandbox_permissions=require_escalated`.

## 1) Inspect comments needing attention
- Run scripts/fetch_comments.py which will print out all the comments and review threads on the PR

## 2) Ask the user for clarification
- Number all the review threads and comments and provide a short summary of what would be required to apply a fix for it
- Ask the user which numbered comments should be addressed

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
python scripts/fetch_comments.py --resolve THREAD_ID [THREAD_ID ...]
```

Notes:
- If gh hits auth/rate issues mid-run, prompt the user to re-authenticate with `gh auth login`, then retry.
- Threads that are already `isResolved` or `isOutdated` should be excluded from the proposal list.
