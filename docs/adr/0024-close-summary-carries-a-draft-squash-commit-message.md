# ADR-0024: The Close Summary Carries a Draft Squash Commit Message

**Date**: 2026-10-21
**Status**: Accepted
**Issue**: [#85](https://github.com/ahayehaye/copilot-agentic-engineering/issues/85)

## Context

When the implementer or director workflow reaches its close step, the close summary reports commits, AC status, and review findings — but no ready-to-use squash commit message. The user hand-crafts the squash message at merge/PR time, re-deriving the subject, body, and ticket-closure lines from the branch. Since squash commits are the default PR flow, this re-derivation happens on every closed feature.

Both workflows close: the implementer's `### Close` section and the director's final step. The base branch is already known in each flow — from the implementer's entry check and the director's step 1 branch check — so the commit range (`git log <base-branch>..HEAD`) is derivable at close time. The ticket numbers being closed are already in hand: the director from the graph, the implementer from the tracker.

## Decision

The close summary of **both** workflows prints a **draft squash commit message** as its last element, in a fenced code block:

- **Always printed** — even when the branch has a single commit. The draft is the canonical close artifact; an existing single-commit message is not assumed to be squash-ready.
- **Derived from the branch's commits** — `git log <base-branch>..HEAD`; the base branch is known from the implementer's entry check / the director's step 1 branch check.
- **Self-contained format** — Conventional Commits; subject ≤ 50 chars; body lines ≤ 72 chars; one `Closes: #<n>` line per ticket being closed, parent first (GitHub does not close multiple tickets referenced on a single line); `Refs: #<n>` lines for reference tickets the spec names (prior art, related issues), if any. The format is written into the agent file text itself, not referenced from the repo's commit-convention doc (`AGENTS.md`).
- **Draft only** — the squash happens at merge/PR time, which is the user's action. The workflow prints the draft; it never commits or squashes itself.

The implementer's `### Close` section gains the close-summary bullet; the director gains a new step 6 "Close", structurally parallel to the implementer's close section, with step 5's tail ("get the user's confirmation before closing any tickets") becoming "then proceed to Close". The two agent files are version-bumped (implementer 0.3.1 → 0.5.0; director 0.11.0 → 0.13.0). The domain glossary gains a Director entry and a close-summary clause on the Implementer entry.

## Considered Options

- **Always print.** Chosen — squash is the default PR flow, and a single commit's message is not evidence it is squash-ready; the draft is the canonical close artifact in every case.
- **Only when more than one commit.** Rejected — it makes the close artifact conditional, so the user cannot rely on the draft being present, and the single-commit case is exactly where the user most often skips re-derivation.
- **Self-contained format in the agent file text.** Chosen — agent files do not carry AGENTS.md in context by construction (per [ADR-0010](0010-shell-safety-rules-live-in-the-skill.md)); the format is four lines and the commit conventions are stable.
- **Reference the commit-convention doc for the format.** Rejected — it would make the close summary depend on a file the agent file does not hold in context, and re-introduce the re-derivation this ADR removes.

## Consequences

- **Positive**: The close summary is a canonical close artifact — the user copies the draft verbatim at merge/PR time instead of re-deriving the subject, body, and closure lines.
- **Positive**: Both workflows produce the same artifact.
- **Positive**: The glossary documents the Director as a first-class term alongside the Implementer.
- **Negative**: The commit-convention format is duplicated in the two agent files; a convention change in `AGENTS.md` must be propagated to the agent files. Accepted — the format is four lines and the conventions are stable.
- **Neutral**: A branch with no commits ahead of the base is a tracker/git contradiction surfaced by earlier checks (AC verification against live state, review over an empty diff), not a close-summary concern; no special case is added.
