# ADR-0010: Shell-Safety Rules Live in the Skill; Instruction Files Carry a Pointer

**Date**: 2026-09-06
**Status**: Accepted

## Context

The shell-safety change set — forklifted from the private side — lands the shell-safety Skill at `skills/shell-safety/` and wires it into the Copilot side. The agent profiles under `copilot-agents/` are touched, and four of them (`worker`, `axis-reviewer`, `reviewer`, `verifier`) preload the skill via a `skills:` frontmatter key.

Before the change set, the two instruction sources (`AGENTS.md` and `copilot-instructions/copilot-instructions.md`) carried the full shell-safety rule list inline. The change set reduces them to a one-line pointer. This ADR records the Copilot-side decision: where the rules live, how the instruction sources reference them, and what parity means when the delivery mechanism differs per session type.

## Decision

- **The shell-safety Skill is the single canonical home of the twelve shell-safety rules.** The rule text lives only in `skills/shell-safety/SKILL.md`.
- **Instruction files carry a one-line pointer, never a copy.** Each instruction source says to consult the shell-safety skill when doing potentially risky or dangerous shell actions; neither restates the rules.
- **The `skills` frontmatter key works only in YAML list form.** The CSV string form silently discards the entire agent profile — the agent does not load at all.
- **The parity bar is behavior, not mechanism.** Parity means identical skill text in every subagent's prompt context; how the text arrives (preloaded, pointed to, or both) may differ per session type.

## Considered Options

- **Keep a copy of the rules in each instruction file.** Rejected — the rules would exist in multiple places that must be kept in sync, and the canonical-home rule would be broken.
- **Single canonical home in the Skill; instruction files carry a pointer.** Chosen — one text to maintain, and the pointer line crosses the forklift byte-identical.
- **CSV string form for the `skills` key.** Rejected — the CLI silently discards the entire agent profile.
- **YAML list form for the `skills` key.** Chosen — the only form the CLI honors.

## Consequences

- **Accepted degradation**: main sessions see the pointer plus the skill list, not the verbatim rules — the full rule text enters the context only when the skill is consulted or preloaded.
- **Accepted degradation**: replace-mode built-in agents carry the skill list but no preload.
- **Positive**: the pointer line in the instruction sources is stable across forklift runs; the instruction file itself is deployed under the install-if-missing lifecycle of [ADR-0007](0007-copilot-instructions-install-if-missing.md), so a drifted Target is never clobbered.
- **Positive**: the same split as [ADR-0009](0009-host-agents-bind-the-harness.md) — the host binds the harness, the skill owns the content — now covers the safety rules, not just execution semantics.
- **Neutral**: the private sibling owns the pi side of this decision (the precedent set by [ADR-0009](0009-host-agents-bind-the-harness.md) naming "the private sibling"); this record covers the Copilot wiring only.
- **Neutral**: the wire-log re-verification seam is to deploy the agents, dispatch a subagent in a debug-logged session, and grep the subagent's wire request for the skill text.
