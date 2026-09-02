---
name: plan-from-docs
description: "Propose a complete plan for a simpler change in one pass, grounded in the project's domain docs and code — no interview. Invoke explicitly; the model never triggers this skill on its own. Unlike /grilling, which must tease serious changes out through Q&A, this skill reads the docs first and puts a full plan on the table up front."
version: 0.2.0
disable-model-invocation: true
---

# Plan From Docs

Docs-first plan proposal for simpler changes. Read the project's domain docs
and relevant code, then propose a complete plan in a single pass — no
interview. The user interrogates the plan in a Q&A loop and revises it until
explicitly accepting.

**When to use.** Invoke explicitly when the change is simple enough that the
project's own docs already carry most of the answer. Use `/grilling` for
serious changes that must be teased out through Q&A.

**The plan stays in-conversation.** Nothing is published to the issue
tracker. The proposed domain-doc updates (glossary terms and ADRs) are
Phase 1 shared-understanding artifacts captured in the spec; their file
materialization is a vertical slice the director dispatches — this
skill never writes them. On acceptance, tell the user the next commands:
`/to-spec` with the accepted plan as its input, followed by `/to-tickets`.
The user runs those commands — the agent never invokes them on the user's
behalf.

## Procedure

### 1. Gather

Read the project's domain docs. If the project has a `docs/agents/domain.md`
(or equivalent), follow it; otherwise use these defaults:

- `CONTEXT.md` at the repo root — or `CONTEXT-MAP.md` at the root if it
  exists; read each context's `CONTEXT.md` that is relevant to the topic.
- `docs/adr/` — the ADRs that touch the area you're about to change. In
  multi-context repos, also check `src/<context>/docs/adr/`.
- Agent docs under `docs/agents/`.

Then do a **targeted** codebase exploration for prior art, existing seams,
and integration points relevant to the change.

This step is **strictly read-only** — no edits, no scratch files. If any of
these docs don't exist, **proceed silently**: don't flag their absence, and
don't suggest creating them upfront.

### 2. Propose

Produce a complete plan, in-conversation, with exactly these six sections:

1. **Summary** — what changes and why, in a few sentences.
2. **Requirements** — what the accepted change must do.
3. **Technical Findings** — data structures, integration points, edge cases,
   and prior art found during Gather.
4. **Proposed Approach** — architecture direction, testing seams,
   trade-offs.
5. **Assumptions & open questions** — every docs gap becomes an explicit
   assumption. Name it, state what you assume, and why.
6. **Proposed domain-doc updates** — new glossary terms and ADRs the change
   would require.

Rules for this step:

- **Zero questions are asked** during the proposal.
- Use the glossary's vocabulary; don't drift to synonyms the glossary
  avoids.
- **Flag ADR conflicts explicitly, never silently override.** If the plan
  contradicts an existing ADR, surface it:
  _Contradicts ADR-0007 (event-sourced orders) — but worth reopening
  because…_

### 3. Revise

Present the plan and invite questions. Answer, revise, and re-present.
Repeat until the user **explicitly accepts** the plan.

**Escape hatch:** if the Q&A reveals the change needs real discovery
(unknowns the docs can't resolve, decisions that genuinely must be teased
out), stop and switch to `/grilling`, carrying everything learned so far —
the Gather findings, the draft plan, and the assumptions — into the
interview.

### 4. Hand off

Only on explicit acceptance, tell the user the next commands: run `/to-spec`
with the accepted plan as its input, then run `/to-tickets`. The pipeline
then continues: the user runs `/to-spec` → `/to-tickets` → new session →
director + `/implement`.
