# ADR-0019: The Skill Is the Migration; Re-Runs Reconcile Drift

**Date**: 2026-09-09
**Status**: Accepted
**Issue**: [ahayehaye/agentic-software-engineering#306](https://github.com/ahayehaye/agentic-software-engineering/issues/306)

## Context

`/setup-alex-skills` enhances a repo already set up by `/setup-matt-pocock-skills` (the enhanced doc's shape is recorded in [ADR-0018](0018-enhanced-tracker-doc-is-self-contained-per-flavor.md)). Already-deployed repos need the same enhancement, and many are in a partial or drifted state: the tracker doc may be hand-edited, and the standard labels may already exist (the source repo's dogfood was exactly that case — the `spec`/`vertical-slice` labels pre-existed and the doc was the pristine upstream template).

The open question is how already-deployed repos are migrated: by the skill itself, or by a separate migration artifact (a wizard or script).

## Decision

The skill is the migration. Already-deployed repos are migrated by re-running `/setup-alex-skills` in-repo; there is no separate wizard artifact.

- **Idempotent re-runs reconcile drift.** On re-run the skill diffs the existing doc against the enhanced form and presents the delta. The delta is additive only: missing sections are added, drifted sections are presented side by side so the user decides, and the user's hand edits are preserved — nothing is silently clobbered. A re-run on an already-enhanced doc is a no-op.
- **Label creation is idempotent.** Missing labels are created with their canonical descriptions; existing labels are left as-is with any description mismatch flagged; duplicates are never created.
- **The inventory of deployed repos is deliberately out of scope.** The owner knows their repos; migration is triggered by opening a session in a repo and running the skill.

## Considered Options

- **A separate wizard artifact** (a migration script or wizard that inventories deployed repos and applies the enhancement). Rejected — it would be a second maintained artifact duplicating the skill's drift-reconciliation logic, it would require an inventory of deployed repos that is deliberately out of scope, and it would run without the user-in-the-loop confirmation (explore → present → confirm → write) that a change to per-repo, user-edited content deserves.
- **The skill is the migration.** Chosen — one artifact, one code path, and the skill's user-in-the-loop gates are exactly what a safe in-repo migration needs.

## Consequences

- **Positive**: Already-deployed repos are migrated by one in-repo action — no second artifact to maintain, no duplicated drift logic.
- **Positive**: Drift reconciliation is a property of the skill's normal operation, so safe re-runs and migration are the same path.
- **Negative**: Migration is per-repo — each deployed repo needs its own session and re-run. Accepted: the owner knows their repos, and the inventory is out of scope.
- **Neutral**: The first instance — the dogfood in ahayehaye/agentic-software-engineering (#308) — is the reference instance for later flavors and repos.

## Provenance

Ported from ahayehaye/agentic-software-engineering, where this decision was recorded as ADR-0020 against the #306 change set (dogfood #308). The decision is unchanged; cross-references use this repo's numbering (the enhanced-doc ADR is [ADR-0018](0018-enhanced-tracker-doc-is-self-contained-per-flavor.md) here), and the date is the landing date in this repo.
