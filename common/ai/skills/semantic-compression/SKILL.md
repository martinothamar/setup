---
name: semantic-compression
description: Deduplicates code by collapsing repeated semantics into one code path while keeping one-off behaviour direct and local. Use when asked to DRY up, dedupe, consolidate, unify, factor out, reduce duplication in, or merge near-identical or copy-pasted functions, branches, tests, types, or parallel code paths. Not for redesigns or reimplementations where the target shape is still undecided.
---

# Semantic compression

Compress by meaning, not by character count. Two blocks are duplicates only if a future change would normally have to touch both; coincidental similarity stays separate. The goal is fewer code paths: every case that does the same thing runs the same code, and each call site holds close to the minimum information unique to its case.

Rules that differ from the obvious refactor:

- No shared helper, type, or layer until at least two concrete call sites prove the shape. When adding behaviour and the shared shape is still uncertain, implement the direct local version first; when an existing abstraction already fits, use it.
- First look for repeated work or decisions that can share one loop, table, or control-flow structure, with the real variation expressed as data. Extraction dedupes the body but leaves N call sites; a loop leaves one path that every case runs and tests. Extract a helper when that still leaves repeated operations across separate uses.
- A loop, table, or merged type only counts as compression if the shared body has no per-case branches. If rows need callbacks, or the body switches on a kind tag or index, the paths still exist and are now hidden in data; keep them separate or find the real shared operation. The same test applies to table-driven tests.
- Match the construct to the repetition: a repeated calculation or decision is a function named after the domain operation; values that move together are a struct; interacting state that several steps read and update is a struct with functions on it from the start. Never bigger than the shape needs.
- Derive counts, sizes, and totals from the steps that produce them instead of declaring them up front where they can drift.
- When a new call site almost fits an existing helper, choose explicitly: use it unchanged, reshape it, layer over or under it, or stay local. Do not add switches merely to force unrelated behaviour into the same helper.
- Name extracted things after the problem domain, not architecture vocabulary (Service, Handler, Strategy, Base, Util).

Decompress when it went wrong: if a call site now needs mode flags, callbacks, nullable arguments, or configuration that is harder to read than the original duplication, split or inline the abstraction. A helper with one real caller after the edit gets inlined unless it owns a derived value or invariant, or marks a boundary the codebase already has.

In the summary, say what was merged and what intentionally stayed local.
