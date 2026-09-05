# ADR-0008: Vendor the workflow's upstream skills in-repo

**Date**: 2026-09-05
**Status**: Accepted

## Context

The agent workflow this repo documents depends on a set of skills maintained upstream in [`mattpocock/skills`](https://github.com/mattpocock/skills). Until now they were an external dependency: the repo's agents and docs referenced them, but they were assumed to be already installed in the environment (typically via `npx skills`), and the repo shipped nothing. That left the deployed skill set unversioned, unattributed, and unreviewable from this repo — an upstream change could silently alter the behavior of every agent in this repo with no trace in this repo's history.

The repo already has the infrastructure to fix this: the **Skill Manager** deploys everything under the skills **Source** (`skills/`) to the **Target** (`~/.agents/skills/`) through the shared version-gated lifecycle.

## Decision

Vendor the workflow's upstream skills in-repo under `skills/`, under the **Skill Manager**. `npx skills` is retired for the `mattpocock/skills` source — the repo ships its own copies and deploys them.

**Three-tier policy.** Every skill under `skills/` is exactly one of:

- **Original** — repo-authored (e.g. `mcp-smoke-test`, `plan-from-docs`). Carries no provenance frontmatter; the absence unambiguously means "we wrote this".
- **Vendored, unedited** — byte-identical to the recorded upstream commit apart from the added provenance frontmatter lines.
- **Vendored, amended** — imported with deliberate local amendments; the amendments stay deliberate, visible commits.

**Provenance frontmatter.** Every vendored skill carries, alongside `name`/`description`/`version`, a spec-conformant frontmatter block recording where the copy came from:

```yaml
license: LICENSE
metadata:
  upstream: mattpocock/skills
  upstream-sha: <40-char commit SHA>
  vendored: unedited | amended
```

**Local monotonic semver.** `version:` on a vendored skill is a local monotonic semver (starting `1.0.0`), bumped on every re-import or amendment — it answers "which copy of this skill is deployed", the manager's only question. The upstream commit SHA is provenance, not a version: for an **unedited** skill it is the exact imported commit and moves with the version on re-import; for an **amended** skill it is the fork point and stays put while the version moves.

**Per-skill bundled license.** Each vendored skill bundles the verbatim upstream MIT `LICENSE` — including the copyright notice — in its own directory, referenced by `license:`. Per-skill rather than shared, so attribution survives any copy-out of an individual skill.

**Zero manager changes.** The Skill Manager and the Shared Library are untouched: a vendored skill is a skill with extra frontmatter, and the existing version-gated lifecycle (install/upgrade/uninstall, backup, semver gating) works on it as-is.

**`code-review` is unedited by public-side choice.** The `code-review` skill is vendored unedited — its two axes (Standards, Spec) run as parallel sub-agents — and keeping it that way is a choice made on this side of the integration, hosted by the `reviewer` agent, which spawns the two axes as `axis-reviewer` children.

## Considered Options

- **Keep `npx skills` (external dependency).** Rejected — the deployed skill set stays unversioned and unattributed in this repo, and an upstream change can silently alter agent behavior with no trace in this repo's history.
- **Vendor with upstream versioning.** Rejected — upstream tags do not track the individual commit a skill was copied from, and the manager's lifecycle needs a version per deployed copy; a local monotonic semver plus the SHA as provenance gives the manager a version and the reader the exact upstream commit.
- **Amend vendored skills in place without recording the fork.** Rejected — an unrecorded amendment makes the diff against upstream unrecoverable; the tier (`unedited`/`amended`) and `upstream-sha` keep the fork point visible.
- **Vendor in-repo under the existing Skill Manager.** Chosen — zero manager changes, the full version-gated lifecycle applies to vendored skills as-is, and every deployed copy is reviewable in this repo's history.

## Consequences

- **Positive**: The deployed skill set is fully visible, versioned, and attributable in this repo; adopting an upstream change is an explicit commit, not silent drift.
- **Positive**: The manager is untouched — vendored skills flow through the same install/upgrade/backup lifecycle as originals.
- **Positive**: Attribution survives per-skill copy-out via the bundled MIT license.
- **Negative**: Re-importing upstream changes is manual work — every re-import or amendment is a deliberate commit with a version bump.
- **Negative**: The forklift that refreshes the vendored set copies the whole skills directory and the agents, so it can overwrite this repo's own choices; a standing rinse re-verifies and re-applies the unedited `code-review` content and the `reviewer` agent's parallel wording after every forklift run (see the [Skills doc](../skills.md#importing-a-vendored-skill)).
