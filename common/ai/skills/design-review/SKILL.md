---
name: "design-review"
description: "Use when the user asks for a design review, code review focused on software design, API design, or code organization. Reviews a module or directory holistically — not style or formatting issues."
---

# Design Review

You are doing a **software design review**, not a style review. Focus exclusively on issues that affect correctness, testability, maintainability, or safety long term.

## Process

**Step 0 — Confirm scope.** Resolve the review target from the user request and available context. If missing or ambiguous, ask one clarifying question and wait. Restate the exact target (path/module) before continuing.

**Step 1 — Map the surface.** Before reading anything in depth, list all in-scope source files in the target and summarize each file's responsibility at a high level.

**Source file definition (default):**
- Include: runtime/business logic, API handlers, domain models, data-access code, schema/migrations, and configuration that changes runtime behavior.
- Exclude: generated files, vendored/third-party code, lockfiles, binaries, build artifacts, and caches.
- Include tests only when they materially clarify intended architecture or invariants.
- If unsure whether a file is in scope, call it out explicitly in assumptions.

**Step 2 — Size gate.** If the target is too large for a single thorough pass (for example: >150 files or >20k LOC), do not pretend to review everything. Ask the user to choose:
- narrow scope, or
- phased review (subdirectories/components reviewed in sequence), or
- parallel subagent review.

If subagents are used:
- Split into non-overlapping slices with explicit ownership.
- Give every subagent the same review rubric and reporting format.
- Merge and deduplicate findings centrally.
- Do a final cross-slice pass for boundary issues (coupling, shared state, init order), since subagents can miss interactions across slices.

**Step 3 — Read comprehensively.** Read every in-scope source file in full before forming conclusions. Do not review files in isolation.

**Step 4 — Reason holistically.** After reading the full in-scope surface, reason across boundaries. Ask: how do modules relate? What crosses boundaries that should not? What state is shared and how?

**Step 5 — Report findings.** For each issue, provide:
- A short title
- The file(s) and approximate location
- What the problem is
- Why it matters (correctness, testability, maintainability, or safety)

## What to look for

**Module boundaries and coupling**
- Does any single file/module handle too many concerns (routing, business logic, config, DB, workers)?
- Are responsibilities clearly separated or entangled?
- Are there circular dependencies or inappropriate imports?

**Duplication and drift**
- Is the same concept represented in multiple places (parallel data structures, mirrored state, duplicated logic)?
- When representations can diverge, which is the source of truth — and is that enforced, or do they risk drifting?
- Is similar logic copy-pasted where a shared abstraction would eliminate the divergence risk?

**Functional core, imperative shell**
- Is I/O, side effects, and impurity pushed to the edges of the system?
- Is core business logic pure and free from infrastructure concerns (DB, HTTP, filesystem, clocks, randomness)?
- Does impure code (input parsing, API calls, DB reads) happen upfront, handing clean data to pure logic — or is impurity mixed throughout?
- Would the core logic be trivially testable if called with in-memory data?

**State management**
- Is mutable state minimized and clearly owned?
- Are config/definition objects being mutated at runtime (conflating static config with transient state)?
- Is shared mutable state protected against concurrent access?
- Are there globals initialized via side effects rather than explicit calls?

**Initialization and configuration**
- Do modules execute side effects on `require`/`import`/`static` constructors (DB connections, file I/O)?
- Is there implicit initialization ordering that could cause failures?
- Are dependencies injected or implicitly assumed to exist?
- Are environment-specific values (paths, ports, URLs, credentials) hardcoded rather than injected from configuration? Could the system target a different environment without code changes?

**Data representation (parse, don't validate)**
- Are inputs parsed into typed, constrained representations at the boundary — or are raw/unvalidated forms passed deep into the system?
- Do data models make invalid states unrepresentable, or do they permit values that require runtime checks throughout?
- Is validation scattered across the codebase rather than centralized at entry points?
- Is data normalized appropriately, or is metadata duplicated across rows/objects?
- Do the schema and queries reflect the actual domain relationships, or do queries work around a schema that doesn't fit the problem?

**API and interface design**
- Do endpoints/functions do one thing, or do they bundle multiple concerns?
- Do action endpoints return state they shouldn't (coupling action + polling)?
- Do operations that take a long time block the caller? Should they be async/decoupled?
- Does the API design allow efficient operation, or does it force callers into chatty/sequential patterns? Are batch APIs available where N+1 patterns would otherwise occur?
- Are error paths and success paths clearly distinguished?

**Safety and injection risks**
- Is SQL or other structured language built by string concatenation?
- Are inputs validated at the right boundaries?
- Are there patterns that are safe now but become unsafe if callers change?

**Performance and efficiency**
- Is work done repeatedly that could be done once (redundant computation, repeated parsing, avoidable allocations)?
- Are there unbounded operations with no limits on collection sizes, parallelism, or request sizes?
- Are bulk/batch operations used where multiple round-trips would be avoidable?

**Testability**
- Can core logic be tested without standing up infrastructure (DB, network, filesystem)?
- Are domain models free from infrastructure dependencies?
- Does module-level state or side effects make unit testing impractical?
- Are tests coupled to implementation details (internal functions, private state, call sequences) rather than observable behavior?
- Is there overlapping coverage where many tests break for the same underlying change?

## Quality bar

Only report issues worth acting on. Skip:
- Style, formatting, naming preferences
- Obvious one-liners that are already clear
- Issues that are purely theoretical with no realistic path to causing problems

Never start the review until target scope is explicit and restated.
