---
name: "distsys-review"
description: "Use when the user asks for a distributed systems review, review of a service architecture, or analysis of correctness, reliability, and operational concerns in distributed or networked systems."
---

# Distributed Systems Review

You are doing a **distributed systems design review**. Focus on correctness, reliability, and operational concerns that only become visible when multiple processes, nodes, or services interact — especially under failure conditions.

The most important class of bugs in distributed systems are the ones that only appear under partial failure, concurrency, or load. Bias toward finding those.

## Process

**Step 0 — Confirm target and boundaries.** If the review target is not specified, ask the user to name the system, service, or directory. Do not proceed until clarified. Confirm boundaries before deep review:
- In-scope services/components
- Datastores, queues, and external dependencies
- Critical invariants (for example: no duplicate charges, no lost events)
- Known constraints (SLOs, rollout model, ordering guarantees)

**Step 1 — Map the surface.** Identify all services, components, datastores, queues, and external dependencies. Understand what communicates with what and how.

**Step 2 — Prioritize and read deeply.** Start with highest-risk paths first (writes, cross-service workflows, retries, coordination, migrations). Read relevant source, config, and infrastructure end-to-end before drawing conclusions. Expand scope until each finding is backed by full boundary context.

**Step 3 — Reason under failure.** For each interaction, evaluate at least: fail, timeout/slow, duplicate, reorder, concurrent execution, partial partition, and mid-operation restart.

**Step 4 — Verify assumptions with evidence.** For each suspected issue, collect concrete evidence from code, configuration, tests, runtime docs, or metrics/logging hooks. If evidence is missing, record it as an open question, not a finding.

**Step 5 — Report findings.** For each issue:
- A short title
- Severity (`Critical`/`High`/`Medium`/`Low`)
- Impact type (`data loss`, `silent corruption`, `consistency`, `availability`, `operability`)
- Component(s) and approximate location
- Failure scenario or condition that triggers it
- Expected behavior vs. actual behavior
- Evidence
- Why it matters
- Recommended fix

## What to look for

Use this as a prompt list, not a box-checking exercise. Prioritize realistic, high-impact failures first.

**Failure handling and resilience**
- Are all failure modes handled, not just the happy path?
- What happens under partial failure (some nodes/services fail, others don't)?
- Are there single points of failure with no failover?
- Do all network calls have timeouts? Are there any infinite waits?
- Are retries implemented with exponential backoff and jitter to avoid thundering herds?
- Are there circuit breakers to stop cascading failures into dependencies?
- Are failure domains isolated (bulkheads), or can one component take down others?

**Idempotency and delivery semantics**
- Are mutating operations idempotent — safe to retry without side effects?
- What delivery guarantee is assumed (at-least-once, at-most-once, exactly-once) — and does the implementation actually provide it?
- Are there duplicate message/request scenarios, and are they handled?
- Are there operations that should be transactional but aren't, leaving the system in a half-applied state on failure?

**Consistency and correctness**
- What consistency model is assumed (strong, causal, eventual)? Is that what the implementation provides?
- Are there race conditions under concurrent access or concurrent writes?
- Are there time-of-check/time-of-use (TOCTOU) races — reading state, then acting on it after another writer may have changed it?
- Does the system rely on wall-clock ordering across nodes (unsafe due to clock skew)? Should logical clocks or sequence numbers be used instead?
- Is there a split-brain scenario — what happens if nodes disagree on shared state?

**Ordering and causality**
- Are there ordering guarantees relied upon that the underlying system doesn't actually provide?
- Can events or messages arrive out of order, and is that handled correctly?
- Are causal dependencies tracked, or can effects arrive before their causes?

**State ownership and data**
- Is there a clear, single owner for each piece of state?
- Is shared mutable state across nodes coordinated correctly?
- Are distributed transactions used? If so, what happens on partial failure — is there compensation/rollback?
- Is state colocated with processing where possible, or is there excessive cross-node state access?

**Coordination and locking**
- Is distributed locking used? If the lock holder crashes before releasing, is the lock eventually released?
- Is there leader election? What happens during failover — is there a period where two leaders exist?
- Are there global barriers or synchronization points that can stall the entire system?
- Can coordination be eliminated in favor of independent local decisions?

**Backpressure and load**
- Is there backpressure to prevent fast producers from overwhelming slow consumers?
- Are queues bounded? Can they grow without limit under load?
- Are there thundering herd scenarios — many clients reconnecting or retrying simultaneously after an outage?
- Are bulk/batch APIs used where N+1 patterns would otherwise occur across the network?

**Observability**
- Are trace/correlation IDs propagated across all service boundaries?
- Is structured logging used consistently with enough context to reconstruct what happened?
- Are failures logged with the information needed to diagnose root cause?
- Are queue depths, error rates, and latency percentiles (not just averages) exposed as metrics?

**API and protocol design**
- Are APIs versioned to support rolling deploys where old and new versions run simultaneously?
- Are schema and protocol changes backward and forward compatible?
- Are long-running operations modeled as async (start → poll for status) rather than blocking?
- Are large result sets paginated with stable cursors rather than offset-based paging?
- Are health check and readiness endpoints present and meaningful?

**Operational and deployment**
- Can the system be deployed in a rolling fashion without downtime?
- Are database/schema migrations backward compatible with both old and new code running simultaneously?
- Are there migrations or data transforms that require careful sequencing or coordination during rollout?
- Can the system be safely scaled horizontally without new failure modes appearing?

## Quality bar

Only report issues worth acting on. Prioritize:
- Issues that cause data loss, silent corruption, or incorrect results
- Issues that cause unavailability or cascading failures under realistic conditions
- Issues where failure only manifests under concurrency or partial failure (easy to miss in testing)

Severity rubric:
- `Critical`: realistic path to data loss/silent corruption or unrecoverable inconsistency
- `High`: realistic path to major availability degradation or persistent incorrect behavior
- `Medium`: reliability/operability issue with bounded blast radius
- `Low`: useful hardening or observability improvement with limited direct risk

Skip purely theoretical concerns with no realistic trigger, and style or naming issues.

## Finding template

Use this format for each finding:

```markdown
### <Short title>
Severity: <Critical|High|Medium|Low>
Impact: <data loss|silent corruption|consistency|availability|operability>
Component: <service/module/path>
Trigger: <failure mode / condition>
Expected vs Actual: <what should happen> vs <what happens>
Evidence: <code/config/runtime references>
Fix: <minimal actionable mitigation>
Confidence: <high|medium|low>
```
