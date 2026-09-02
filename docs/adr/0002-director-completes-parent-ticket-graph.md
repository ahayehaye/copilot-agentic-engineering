# ADR-0002: The Director Completes the Parent Ticket's Dependency Graph

**Date**: 2026-08-22
**Status**: Accepted

## Context

The planning pipeline (analyst: `/grilling` or `/plan-from-docs` → `/to-spec` → `/to-tickets`) produces a parent ticket with vertical slice children, each declaring its Blocking Edges. Execution then begins with `/implement`. The workflow notes describe `/implement #<ticket>` run per sub-issue, while the director agent is defined to take the **parent** ticket number and orchestrate all of its slices. Both readings could not be authoritative at once.

## Decision

The director owns **completing** the parent ticket's dependency graph. `/implement #<parent-ticket-number>` (e.g. `/implement #100`, where #100 is the parent of slices #101, #102, …) is the single execution entry point: the director builds the dependency graph from the slice tickets, dispatches workers in dependency order, verifies each slice's Acceptance Criteria, and closes tickets only after explicit user confirmation.

**Edge definition stays with `/to-tickets`.** The analyst defines Blocking Edges during planning; the director consumes them and never redefines them. When a slice's edges cannot be read, the director treats it as blocked and asks the user rather than guessing.

Dispatch is **sequential** in dependency order. Parallel dispatch of independent slices is deliberately deferred (workers share a single checkout; concurrency is a later, separately evaluated change).

## Consequences

- **Positive**: One orchestration point per effort; the director can coordinate retries, re-slicing, and review across the whole graph instead of per slice.
- **Positive**: With tickets as the only state storage (verification comments, checkbox updates), a fresh session can rebuild execution state from the tracker alone.
- **Negative**: The director's session must live across a multi-slice effort; long efforts may need session restarts that rely on the ticket-rebuilt state.
- **Neutral**: The workflow notes still describe the per-sub-issue variant of `/implement`. This divergence is known and intentionally not updated as part of this change.
