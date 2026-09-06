# ADR-0009: Host Agents Bind the Harness, Not the Skill's Execution Semantics

**Date**: 2026-09-05
**Status**: Accepted

## Context

The `reviewer` Copilot Agent hosts the `code-review` skill. Its file re-stated the skill's axis spawn mode ("Delegate the skill's two axes in parallel…"), duplicating a decision the skill itself prescribes. The duplication had to be forked per repo: this repo vendored the skill unedited (parallel axes) and carried parallel host wording; the private sibling amended the skill (sequential) and carried sequential host wording. The forklift that refreshes this repo from the private side overwrites the host file on every run, so the local wording had to be re-applied by the standing rinse after every forklift run — and the last run overwrote it anyway, along with the director's Version and the Skills doc's public-owned edits.

## Decision

A host agent file must not restate execution semantics the hosted skill prescribes (spawn mode, prompt content). It binds only the harness facts the skill cannot know: the tool that runs the delegation (`task`) and the child agent type (`axis-reviewer`). The Code-Review Skill is the single source of truth for how its axes run.

## Considered Options

- **Restate the spawn mode in the host file.** Rejected — the duplication forks per repo (each side's host wording must match its own vendored skill copy), the forklift overwrites it on every run, and keeping it in sync is a standing manual item.
- **Bind the harness only; the skill owns the execution semantics.** Chosen — the host file is identical on both sides, crosses the forklift byte-identical, and a per-side skill amendment is host-transparent.

## Consequences

- **Positive**: The skill is the single source of truth for how its sub-agents run; a per-side skill amendment (the private-side sequential amendment) is host-transparent.
- **Positive**: The `reviewer` file crosses the forklift byte-identical to the private-side 0.4.1 copy, so a forklift re-run is a no-op for the agents directory.
- **Positive**: The standing rinse's reviewer-wording item is retired; the current rinse scope is recorded in [ADR-0008](0008-vendor-upstream-skills-in-repo.md).
- **Neutral**: Axis mode is decided per side by which copy of the skill each repo vendors — that is the designed mechanism, not a defect.
- **Neutral**: The `director`'s `version:` field identifies the forklift copy its body carries; aligning 0.8.2 → 0.8.1 is an alignment to that copy, not a content regression, and deploys via one documented `--reinstall` pass because the manager's version gate refuses downgrades.
