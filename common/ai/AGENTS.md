# AGENTS.md

Default workflow for coding tasks. Treat these as preferences, not laws; task-specific instructions and user intent take priority.

- State important assumptions when they affect the implementation
- Stop and ask when something is unclear or ambiguous
- Challenge flawed approaches, do not validate bad architecture or flawed logic
- Architecture and design can only be judged with future goals and plans in mind; ask if you dont know
- Verify all claims (see verification section below)
- If uncertain and unable to verify in any meaningful way, say "I am not sure" or "I cannot confirm" instead of guessing or agreeing
- Change and fix code at the appropriate level/layer (ask if unclear)
- All changes should be tied to goals, plans and desired outcomes
- Changesets should not include completely unrelated changes unless explicitly asked for
- Simplicity and readability is important

Common mistakes to avoid:

- Adding validation and fallbacks at the wrong layer, when the invalid/wrong state could be made unrepresentable/impossible at the correct (typically outer) layer instead
- Leaving behind old or dead code for compatiblity instead of cleaning up doing refactors/compression. If tests/benchmarks are only callers left, refactor or remove them. Prefer full cleanup
- Filling a proposal, solution or plan with assumptions, caveats, and "if X then Y" branches instead of doing the work to find out. When facts are available, check the code, docs, specs, logs, or other primary sources first, then present specific, concrete plans/solutions based on findings

## Verification

- Define what success looks like before editing when the task is nontrivial
- Form theories, make statements and decisions, apply code changes and similar based on empirical proof or strong references. Examples:
  - Standards and specifications if relevant to the topic, e.g. IETF/IEEE/ISO
  - Online documentation
  - Relevant code/repositories checked out locally (see references section below)
  - Bugfixing: 
    - "red-green" in red-green-refactor, find or build a failing test and then make changes that lead to success
    - Manual reproduction steps and observed behavior
    - Telemetry (metrics, logs, traces, output)
  - Optimization: 
    - Benchmarking for statistically significant (reproducible) measurements
    - Profiling (e.g. CPU, memory) for scoping/directing effort
    - Telemetry (perf counters, metrics, logs, traces)
- Iterate and make changes in small increments
- Re-test and re-prove
- If full verification is impractical, run the lightest useful check and say what remains unverified

## References

References in the form of:

- Code/third party repositories
- Documentation, PDFs

And similar, can be downloaded/cloned to `~/code/reference/`.
Create the folder if it doesnt exist.
Make sure to check for existing content there first.
