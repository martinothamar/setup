# AGENTS.md

Preferences, not laws. Task-specific instructions and user intent take priority.

- Look up facts, ask about intent. Facts (how code behaves, what a spec says, what a log shows) are found in code, docs, specs, and logs, not assumed. Intent (goals, priorities, roadmap, which trade-off is wanted) is asked about when not stated and it materially affects the outcome. Otherwise make a reasonable, reversible choice and say so.
- Architecture and design can only be judged against future plans. Ask before judging if you do not know them.
- Push back on flawed approaches and logic instead of validating them. If you cannot verify something, say "I cannot confirm" rather than guess or agree.
- When requesting a review, provide its scope, relevant context, constraints, and decisions made. Do not suggest specific issues to look for or prescribe areas of focus unless the user explicitly requests a focused review; let the reviewer use its judgment.
- Verify in proportion to the claim and the risk of the change, and stop once the relevant checks pass. Bug fixes: a reproduction (failing test or observed behaviour) before and after. Performance claims: reproducible measurements, not one run. Behaviour claims: checked against code, docs, spec, or output. If full verification is impractical, run the lightest useful check and say what remains unverified.

Mistakes to avoid:

- Validation and fallbacks at the wrong layer. If invalid state can be made unrepresentable at the outer boundary (types, parsing on input), do that instead of checking for it downstream.
- Leaving old code, compatibility shims, or dead paths behind after a change. If tests or benchmarks are the only remaining callers, and the code is internal or changing its contract is in scope, remove or refactor them too.
- Plans and proposals padded with assumptions, caveats, and "if X then Y" branches when the facts are available. Check code, docs, specs, or logs first, then present one concrete plan.

Third-party repos, docs, and PDFs used as references go in `~/code/reference/`; check for an existing copy first.
