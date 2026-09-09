# ADR-0018: The Enhanced Tracker Doc Is Self-Contained per Flavor

**Date**: 2026-09-09
**Status**: Accepted
**Issue**: [ahayehaye/agentic-software-engineering#306](https://github.com/ahayehaye/agentic-software-engineering/issues/306)

## Context

The tracker-dependent workflow skills (notably `verify-ac`) read the project's tracker doc (`docs/agents/issue-tracker.md`) at run time. The upstream Matt Pocock tracker templates define only the basic operations (create, read, list, comment, label, close) plus wayfinding — not what the `verify-ac` protocol needs: slice discovery, body edit (checking AC boxes), or the standard label taxonomy with the label-application rule.

The `/setup-alex-skills` skill (spec ahayehaye/agentic-software-engineering#306) adds those operations to the repo's tracker doc, shipping the enhancement content as a per-flavor template file (currently `issue-tracker-github.md`). The open design question is where the concrete commands and the label-application rule live: in the per-repo tracker doc, or in the skill's template file. The spec resolved it as option B — the enhanced doc is self-contained per flavor.

## Decision

The enhanced tracker doc is self-contained per flavor.

- **The concrete commands and the label-application rule live in the per-repo doc.** The enhancement appends three sections, in the tracker flavor's own concrete commands: slice discovery (all three GitHub mechanisms, documented as strict-union inputs — the strict-union rule itself stays in the `verify-ac` protocol), body edit (the REST PATCH form with the body supplied as a JSON file input; the form-field body form is explicitly forbidden — it mangles newlines), and the standard label taxonomy (exactly two labels — `spec` and `vertical-slice` — created idempotently) with the label-application rule (a spec published by `/to-spec` is created with the `spec` label; a slice published by `/to-tickets` is created with the `vertical-slice` label). Any agent in any session can execute the operations from the doc alone, without cross-referencing any skill's binding example.
- **Per-repo drift is an accepted cost.** The doc is per-repo content and the enhancement is additive: the upstream sections (conventions, PR-surface flag, wayfinding) are preserved untouched, and the user's hand edits are preserved on re-run (drift reconciliation — [ADR-0019](0019-setup-alex-skills-is-the-migration.md)). This is consistent with what the upstream setup already stores per repo.
- **The `verify-ac` skill's GitHub binding remains a documented example.** The skill's protocol delegates to the **tracker binding** defined in the doc; the GitHub binding in the skill is an example of one binding, not the source of commands.
- **The vendored publishing skills stay byte-identical ([ADR-0008](0008-vendor-upstream-skills-in-repo.md)).** `to-spec` and `to-tickets` do not apply the labels themselves; they already defer to the tracker doc, and the label-application rule now lives where they already look.

## Considered Options

- **Commands only in the skill binding.** The tracker doc stays the upstream template and the skills carry the concrete commands. Rejected — the doc is what every session reads at run time, and a skill's binding is flavor-specific (GitHub) while the workflow is tracker-agnostic; an agent in a session that does not run that skill would have to cross-reference the skill's example to execute the operations, and the doc would not be self-contained.
- **Amend the vendored skills.** Rejected — ADR-0008 keeps the vendored Matt Pocock skills byte-identical, and amending `to-spec`/`to-tickets` to apply the labels themselves would couple every re-import to a local amendment that is GitHub-specific while the skills are flavor-neutral. The publishing skills already defer to the tracker doc, so the rule belongs in the doc.
- **Self-contained per-flavor doc.** Chosen — the operations are executable from the doc alone, the skills stay flavor-neutral, and the vendored skills and templates are untouched.

## Consequences

- **Positive**: The enhanced doc is executable from the doc alone — an agent in any session needs no cross-reference to a skill's binding example.
- **Positive**: The vendored skills and templates stay byte-identical (ADR-0008); no re-import coupling, no per-flavor amendment.
- **Negative**: Per-repo drift is accepted — the same operations are restated per repo, and user hand edits can drift the doc from the enhanced form. Mitigated by the skill's drift reconciliation on re-run (ADR-0019).
- **Neutral**: The `verify-ac` skill's GitHub binding is demoted to a documented example — the relationship the **Tracker binding** glossary entry already describes.
- **Neutral**: The reference instance for later flavors and repos is the first instance — the dogfood in ahayehaye/agentic-software-engineering (#308).

## Provenance

Ported from ahayehaye/agentic-software-engineering, where this decision was recorded as ADR-0019 against the #306 change set (dogfood #308). The decision is unchanged; cross-references use this repo's numbering (the vendored-skills ADR is [ADR-0008](0008-vendor-upstream-skills-in-repo.md) here, the migration ADR is [ADR-0019](0019-setup-alex-skills-is-the-migration.md) here), and the date is the landing date in this repo.
