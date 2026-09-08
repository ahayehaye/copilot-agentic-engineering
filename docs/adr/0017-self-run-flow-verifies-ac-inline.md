# ADR-0017: The Self-Run Flow Verifies ACs Inline; the Verifier Stays Dispatch-Only

**Date**: 2026-09-07
**Status**: Accepted
**Issue**: [#38](https://github.com/ahayehaye/copilot-agentic-engineering/issues/38)

## Context

The self-run implementation flow ([ADR-0016](0016-implementer-is-a-guide-in-the-users-session.md)) has the user run `/implement` in their own session, guided by the implementer. Nothing recorded that the slices' acceptance criteria were checked: after `/implement` finished, the tracker showed unchecked AC boxes and no verification comments. The implementer's state machine could never reach the "every slice AC-verified" state that names `/code-review`, and a cleared session could not reconstruct the verified state from the tracker alone.

The fix first proposed in #38 dispatched the verifier (the [ADR-0002](0002-director-completes-parent-ticket-graph.md) role) once per slice from the implementer, with fixed-format verdict records. That design was live-tested and rejected: each per-slice dispatch costs a fresh inference session (sub-agents are bound to the harness per [ADR-0009](0009-host-agents-bind-the-harness.md)), and the identically formatted verdict record was more structure than the self-run flow needs.

What remained required: every slice's ACs checked, the verified state durable and machine-detectable, and no sub-agent dispatch or fixed-format record involved.

## Decision

The self-run flow verifies ACs **inline** via a new repo-original skill, `verify-ac`. The user runs `/verify-ac #<parent>`; the skill discovers the parent's slices (union of the sub-issues endpoint and the `Part of #<parent>` body search), fetches each slice's ACs verbatim from the ticket, runs each check against live repository state, posts a loose per-AC comment on each slice, checks the slice's AC checkboxes, and posts one summary comment on the parent when every slice passes.

- **The checked AC box is the verified marker.** The implementer's state machine is re-keyed from "AC-verified comments" to "every AC checkbox in every slice body is checked." Since the vendored `/implement` skill never touches tickets, a checked box is a true verified marker produced only by `/verify-ac` (or by hand). The per-AC comments are a loose, human-readable record owned by the skill — never parsed by the state machine.
- **The verifier stays dispatch-only.** The `verifier` role is used only in the director/worker flow ([ADR-0002](0002-director-completes-parent-ticket-graph.md)): the worker dispatches it per slice, the director dispatches it for final verification. The implementer gains no dispatch capability; its tool surface and edit rule are unchanged — the skill-bound category covers all ticket edits the skill makes. [ADR-0016](0016-implementer-is-a-guide-in-the-users-session.md) is not amended.

## Accepted Loss and Mitigations

The self-run flow accepts the loss of **fresh-context adversariality**: the same session that did the work verifies it. Mitigations:

- **ACs are fetched verbatim from the ticket** — the verification is framed by the tracker, not by what the session context remembers.
- **`/code-review` remains the fresh-context gate** — the review skill spawns its own sub-agents in fresh contexts, and the two-axis review runs after verification, against the diff since the fixed point.

## Considered Options

- **Per-slice verifier dispatch** (the original #38 design): the implementer dispatches the ADR-0002 verifier once per slice and posts fixed-format verdict records. Rejected — live-tested and rejected: it costs a fresh inference session per slice, and the identically formatted verdict record is more structure than the self-run flow needs.
- **Implementer-inline verification with a third edit category**: the implementer verifies the ACs itself and edits the tickets under a new "verification-bound" category. Rejected — it breaks ADR-0016's total two-category edit rule, and it verifies in the same context that did the work.
- **Inline `verify-ac` skill, user-run.** Chosen — the user runs the skill in their own session (the guide pattern stays total), the verification is inline (no dispatch cost), the record is durable and machine-detectable (checked boxes), and the record format is loose and owned by the skill.

## Consequences

- **Positive**: The self-run flow has a durable, machine-detectable verified state — a cleared session reconstructs "every slice AC-verified" from the checked boxes alone, and `/code-review` is always named only after verification.
- **Positive**: No per-slice dispatch cost in the self-run flow — the verification runs inline in the user's session.
- **Negative**: The self-run flow loses the fresh-context adversariality the ADR-0002 verifier provides in the director flow. Accepted and mitigated (ACs fetched verbatim from the ticket; `/code-review` as the fresh-context gate).
- **Neutral**: The flows are now asymmetric on purpose — the self-run flow verifies inline, the director flow dispatches the verifier. This ADR records the asymmetry so it is explained, not puzzling.
- **Neutral**: The self-run pipeline gains a step: `/implement` → `/verify-ac` → `/code-review`.
