# ADR-0016: The Implementer Is a Guide in the User's Session, Not an Executor or a Watcher

**Date**: 2026-09-07
**Status**: Accepted
**Issue**: [#32](https://github.com/ahayehaye/copilot-agentic-engineering/issues/32)

## Context

The analyst agent already guides Phase 1 (planning): the user runs the skills (`/grill-with-docs` or `/plan-from-docs`, `/to-spec`, `/to-tickets`), the analyst names the next command at each acceptance gate, never *initiates* a skill itself, and reconstructs state from the tracker. Phase 2 (implementation) had no equivalent. The only option was the director, which orchestrates the slices through per-slice worker dispatch, a verifier per slice, a journal, a review loop, and a final verifier.

The director is slow for small changes because of context windows, not work: per slice it pays a fresh worker context (re-reads AGENTS.md, re-fetches the ticket, re-explores the repo), a verifier dispatch, journal bookkeeping and reconcile greps at every checkpoint — then the review loop and a final verifier. Each subagent is a full inference session rebuilding context from zero. For a small change the user would rather drive the implementation themselves — running the skills in their own session — with a guide that names the commands, checks preconditions, tracks progress, and interprets halts and findings.

The open question was the shape of that guide. Two shapes were rejected before the chosen one.

## Decision

The **implementer** is a thin guide for the user-run implementation phase, mirroring the analyst's discipline applied to Phase 2. The user runs `/implement` and `/code-review`; the implementer names the command with the correct arguments, checks preconditions, tracks progress, and interprets halts and findings. It never *initiates* a skill run and never makes a free-form edit. The seat distinction is the decision: what was rejected was the self-initiating executor, not the execution of user-invoked workflows — a user invocation loads the skill's content into the shared session context, and the implementer executes the loaded workflow.

- **Guide execution model.** A user invocation loads the skill's content into the shared session context — the same context the implementer shares — and the implementer executes the loaded workflow; nothing runs in a sub-agent context window. A loaded skill's pointer to another skill is never executed — it converts to naming that command at the state that names it (**chaining**). There are no sub-agents (the only sub-agents that ever run are the ones the code-review skill spawns internally) and no journal. The tracker (tickets and their comments) and git are the only state, so the implementer survives a cleared session for free: it reconstructs where things stand from those alone. This on-demand reconstruction is the recovery story that replaces the director's journal.
- **Skill-bound / instruction-bound edit rule.** The implementer's editing is bounded to two categories. A **skill-bound** edit is one made under the authority of a loaded skill workflow — the implementer names the command, the user invokes the skill, and the loaded workflow makes the edit. An **instruction-bound** edit is one the user explicitly instructs — the implementer applies it because the user, not the implementer, owns the decision. The implementer makes no other edit: no implementation code, no authored docs, no ticket edits on its own initiative. It never closes tickets or pushes branches — those are the user's actions.
- **Note-not-gate scale boundary.** The implementer is the self-driven alternative to the director, not a replacement for it. When the open work is more than a handful of slices, the implementer notes that the director may be the better tool — a note, not a gate: it names the option and defers to the user, who may proceed with the implementer regardless.

## Considered Options

- **A streamlined one-shot executor.** A single-context agent that executes the slices inline — inline verification, one retry, review via the code-review skill, a scope gate, no journal. Rejected — it re-encoded the implementation procedure in the agent file (or forced a skill amendment to own a "single-context mode"), and it put the agent, not the user, in the driver's seat. The guide keeps the skills' domain awareness (vertical slices, blocking edges, ACs) in the user's own context, where the work happens.
- **A tracker-watching co-pilot.** An agent that watches the tracker continuously and co-pilots the user by reacting to tracker events. Rejected — it puts the agent in a co-pilot seat (driving alongside the user) rather than a guide seat (the user drives, the agent responds), and it implies a persistent watcher the reactive session model does not support. The watcher is also unnecessary: the on-demand reconstruction from the tracker and git already provides the recovery story (surviving a cleared session) without a poll loop. The guide is reactive — it reconstructs state when asked ("where are we?") — not a proactive watcher.
- **A guide in the user's session, mirroring the analyst.** Chosen — the user runs the skills; the implementer names the next command at each gate, checks preconditions, tracks progress from the tracker and git, and interprets halts and findings. No sub-agents, no journal, no re-encoding of the implementation procedure; the tracker and git are the only state.

## Consequences

- **Positive**: The small-change scenario no longer pays the director's full context-window cost — the user drives the skills in their own session, and the implementer adds process awareness (precondition checks, correct command arguments, progress reconstruction, a named decision at every halt) without the per-slice dispatch/verify/journal overhead.
- **Positive**: The tracker and git are the only state, so the implementer survives a cleared session for free — no journal to reconcile, no bookkeeping to drift.
- **Positive**: The two-phase workflow is now symmetric — the analyst guides Phase 1, the implementer guides Phase 2 — with a clean hand-off: the implementer detects "no tickets" and defers to the analyst rather than duplicating Phase 1.
- **Negative**: The implementer is not a director alternative for large, hands-off, multi-slice runs — the note-not-gate boundary names the director as the better tool when the open work is more than a handful of slices, but does not block the user.
- **Neutral**: The implementer's tool surface includes file-editing tools (for instruction-bound edits) but no sub-agent dispatch tools — the no-sub-agents rule is enforced structurally, not by prose.
- **Neutral**: The final review in the user-run flow is hosted by the user's session — the user runs `/code-review` directly, and no reviewer role is involved. This distinguishes it from [ADR-0009](0009-host-agents-bind-the-harness.md) rather than contradicting it: ADR-0009 governs the director-run flow, where the director dispatches the reviewer to host the skill. In both flows the code-review skill's two-axis methodology is unchanged; only the host differs.
- **The guide pattern is ADR-only.** The guide pattern — the shared discipline of the analyst and the implementer: the user runs the skills, the agent names the next command, the tracker is state — is recorded here, ADR-only. It has no glossary entry; the glossary's Implementer entry summarizes the implementer's decisions and points here for the *why*.

## Provenance

Ported from the private side, where this decision was recorded against [#275](https://github.com/ahayehaye/agentic-software-engineering/issues/275). The ADR keeps its private-side number (0016): the forklifted implementer profile hard-cites this ADR by path, and mirroring the number keeps the profile byte-identical across the forklift. The 0011–0015 gap in this repo's ADR sequence is deliberate — do not renumber.
