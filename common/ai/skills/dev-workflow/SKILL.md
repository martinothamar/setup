---
name: "dev-workflow"
description: "Use for implementation/refactor/debug tasks that change code. Enforces workflow phases and final response contract for development work."
---

# Development Workflow

Use this workflow only for implementation/refactor/debug tasks that change code.

## Mandatory workflow

For non-trivial implementation/refactor/debug tasks, use this sequence and do not skip phases:

- Phase 0 - Prior-art scan
  - Search the codebase for existing patterns/utilities before designing new code
  - Prefer extending/consolidating existing implementations over adding parallel logic
  - If similar code is not reused, explain why (mismatch, constraints, or risk)
  - Read any AGENTS.md, README.md and relevant documentation in root and relevant child directories
- Phase 1 - Design (no code edits yet)
  - Provide 2-3 viable approaches with tradeoffs: complexity, maintainability, performance, and risk
  - Recommend one approach
  - Ask the user which design to proceed with
- Phase 2 - Implement
  - Implement only the selected design
  - Keep the diff minimal and avoid new duplication
- Phase 3 - Simplify
  - Re-read the code and remove redundancy, dead code, and over-abstractions
  - Consolidate repeated logic/test setup using helpers or table-driven tests when reuse is real
- Phase 4 - Verify
  - Run relevant checks (lint, tests, static analysis, type checks) before finalizing
  - If checks cannot run, state exactly which commands were not run and why
- Phase 5 - Review
  - Make a review pass over the edited code
  - For larger changes (>= +-100 lines), dispatch a subagent for independent review
  - Respond according to final response contract as described below

For trivial implementation edits, use a lightweight version of this flow, but still do a self-review and verification pass.

Never finalize implementation work without an explicit DRY/simplification pass.

## Final response contract

Keep output concise and include:

- Design decision summary
- Prior-art/reuse summary (what existing code was considered, reused, or intentionally not reused)
- Simplification summary (what duplication/redundancy was removed)
- Verification and review summary (commands run + outcome, code strengths and weaknesses if any)
- Ask if the user wants an independent review from a subagent
