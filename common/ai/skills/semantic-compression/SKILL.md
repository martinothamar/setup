---
name: "semantic-compression"
description: "Use when simplifying existing working code by compressing repeated semantics, reducing duplication, or merging parallel code paths. Do not use for broad redesigns, reimplementations, or architecture changes where the target shape is still being decided."
---

# Semantic Compression

Use this skill when the current task is to simplify existing working code by compressing repeated semantics, reducing duplication, or merging parallel code paths.

Do not use it for broad redesigns, reimplementations, or architecture changes where the target shape is still being decided.

Semantic compression is a bottom-up refactoring discipline. Treat the code like something to compress by meaning, not just by text size: repeated or strongly similar semantics should move through the same code path, while one-off behavior should stay direct and local.

## Core rules

- Make code usable before making it reusable.
- Do not introduce a shared helper, type, interface, class hierarchy, configuration layer, or framework until there are at least two concrete call sites or examples that prove the shared shape.
- Try compressing first without introducing helper functions. Ask whether similar work can be merged through loops, tables, or reordering.
- Compress semantics, not characters. Shorter code is not better if it hides the important behavior, couples unrelated cases, or makes debugging harder.
- Let abstractions emerge from working code. Prefer extracting real repeated data and operations from existing examples over designing speculative "model" objects up front.
- Keep unique code close to its use. Do not route one-off behavior through generic machinery just so it looks uniform.
- Look for separate concepts that only differ by name, location, or incidental details. If they share the same behavior and lifecycle, consider representing them as one concept with explicit data for the real variation.

## Workflow

1. Start from behavior.
   - Identify the user-visible or caller-visible behavior that must be preserved.
   - If adding behavior, first implement the direct local version and verify it works; only then look for repeated semantics to compress.
   - Find the relevant tests or commands before editing. If none exist, decide the lightest verification that can catch regressions.

2. Map repeated semantics.
   - Read the nearby code and list concrete repetitions: duplicated control flow, mirrored data calculations, repeated setup, parallel state, copy-pasted tests, or call sites that differ only in domain values.
   - Separate true semantic repetition from coincidental similarity. Two blocks are compressible only when future changes should normally affect them together.
   - Notice parallel concepts that drift in lockstep. If two concepts would usually need the same edits, tests, or invariants, they may be one concept with parameters rather than two concepts.

3. Choose the smallest compression.
   - Before adding a helper, type, object, or other construct, check whether repeated work can be made direct by merging control flow, using data tables, or reordering operations.
   - For repeated calculations or decisions, extract a function with the problem-domain name when direct merging is not enough.
   - For repeated groups of values that move together, introduce a small data structure or existing local type when plain data or a table is not enough.
   - For repeated procedural setup that shares evolving state, consider a small helper object or shared context when passing that state through functions would obscure the behavior.
   - Remove pre-counts, duplicated state, and declarations that can drift from the operations they describe; derive them from the concrete steps when possible.
   - For repeated tests, use a table or fixture only when it makes the behavior easier to scan.
   - When a new call site nearly fits an existing helper, decide explicitly whether to use it unchanged, reshape it, layer over or under it, or leave the code local.
   - Reuse an existing local abstraction when it fits; otherwise keep the new abstraction narrow.

4. Re-read the call sites.
   - The remaining code should be close to the minimum information needed to express what is unique about each case.
   - If a call site now has flags, callbacks, nullable arguments, or configuration that are harder to understand than the original code, decompress or split the abstraction.
   - If the helper has only one real use after the edit, inline it unless it represents a clear boundary already established in the codebase.

5. Verify and report.
   - Run the relevant tests, type checks, or smoke checks.
   - In the final response, summarize what semantic repetition was compressed, what intentionally stayed local, and what verification ran.

## Compression checks

Before finalizing, ask:

- Did this remove a real source of duplicated meaning or drift?
- Is the diff negative, or is any added code clearly buying less duplicated meaning and simpler future changes?
- Did this merge accidentally separate concepts, while preserving any real domain difference explicitly?
- Would the next similar change require fewer edits in fewer places?
- Is the control flow still easy to follow from the call site?
- Did the names come from the problem being solved rather than from generic architecture vocabulary?
- Did I avoid broad cleanup, speculative extensibility, and unrelated refactors?
