# ADR-0020: ADO Work-Item Operations Delegate to the ado-boards Skill

**Date**: 2026-09-17
**Status**: Accepted
**Issue**: [ahayehaye/copilot-agentic-engineering#73](https://github.com/ahayehaye/copilot-agentic-engineering/issues/73)

## Context

The forklift crossed the ADO (Azure DevOps) work-item support from the private upstream repo as the `ado-boards` skill (v1.0.2). The open question is where ADO work-item knowledge lives in a repo onboarded to ADO: in the tracker doc, in the workflow skills, or in a dedicated skill.

## Decision

ADO work-item operations delegate to the `ado-boards` skill.

- **Binding data in the tracker doc, command knowledge in the skill.** The repo's tracker doc carries binding data only — org, default project, surface. All command knowledge (the `az boards` command set, raw-REST recipes, preflight, onboarding) stays in the skill.
- **Org resolved at runtime, never hardcoded.** Resolution order: the tracker doc (authoritative for the repo), the git remote via `--detect`, the az config default, or ask the user.
- **az configuration is check-only, never mutated.** The skill reads config defaults (`az devops configure -l`) and never writes them, unless the user explicitly asks.
- **Guarded deletes.** No `--destroy`; explicit confirmation before `--yes`.

## Considered Options

- **ADO support in the workflow skills** (`/to-spec`, `/to-tickets`, `/implement`, `/verify-ac`). Rejected — it would fork the workflow skills per tracker flavor; the skill's hybrid tracker-doc template is the intended coexistence shape for target repos.
- **Delegate to the `ado-boards` skill.** Chosen — one artifact carries all command knowledge; the tracker doc stays a thin binding; this repo's own tracker doc stays GitHub-only.

## Consequences

- **Positive**: ADO work-item requests in an onboarded repo load one skill; the workflow skills remain tracker-flavor-neutral.
- **Positive**: The skill crosses the forklift with its versions like other private-repo-owned skills; the standing rinse in the [Skills doc](../skills.md#standing-rinse) covers its rinsed line.
- **Negative**: This repo is not onboarded to ADO — the skill ships as a product for target repos.
- **Neutral**: The skill's documented v1.1 extension point (real comment threads via the REST comments/threads API) is out of scope for this landing.
