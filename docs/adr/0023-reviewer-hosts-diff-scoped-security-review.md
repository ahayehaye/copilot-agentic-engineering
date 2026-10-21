# ADR-0023: The Reviewer Hosts a Diff-Scoped Security Review Alongside the Code-Review Skill

**Date**: 2026-10-21
**Status**: Accepted
**Issue**: [#85](https://github.com/ahayehaye/copilot-agentic-engineering/issues/85)

## Context

The final review of a change — the gate that runs after all vertical slices are complete (director flow) and after all AC boxes are checked (implementer flow) — covered only two axes: Standards and Spec. Security properties of the change were never reviewed before close.

The `security-review` skill is already vendored (tier unedited, upstream `github/awesome-copilot`) and deployed to the shared skills directory. Nothing in the workflow ran it.

The skill's default scope is the **entire project** from the root; it also accepts a path scope (`/security-review <path>`), which is the seam this decision uses. The review loop's contract is "review the changes since the fixed point" — the same contract the code-review skill pins with its fixed-point diff command.

## Decision

The final review gains a security lens, hosted by the existing reviewer role:

- **Merged, not a new role.** The `reviewer` hosts the `security-review` skill alongside the `code-review` skill, run via the skill tool, mirroring how it runs the `code-review` skill. The reviewer's description becomes "thin host for the review skills" (plural); it remains edit-tool-free. The handoff contract gains no new inputs: the security scope derives from the fixed point the caller already supplies.
- **Diff-scoped.** The reviewer derives the changed-file list from the same fixed-point diff command the code-review skill pins (`git diff <fixed-point>...HEAD`), with `--name-only` added for the file list, and passes it as the scan scope to `security-review` (the skill's own path-scope feature). Unchanged code is out of scope for the gate.
- **Ordering.** The security review runs after the two-axis code-review. The two reviews are independent; sequencing the primary gate first appends to the existing flow rather than reordering it.
- **Output.** The handoff contract's Output changes from "the two-axis report, verbatim" to "the code-review report and the security-review report, verbatim." The skill owns the report format; the host does not rerank.
- **Director loop.** The director judges security findings alongside Standards/Spec findings; significant findings get the same fix-worker treatment (fix worker dispatches the verifier as a regression check; the director judges resolution).
- **Implementer flow.** The pipeline extends to `implement → verify-ac → code-review → security-review → close`. After a clean or accepted code-review, the implementer names `/security-review` with the changed-file list as the scope argument — never bare.
- **Skills untouched.** `security-review` stays vendored-unedited; `code-review` is not modified by this change.

## Considered Options

- **Whole-project scan.** Rejected — the skill's default. A whole-project scan mixes pre-existing findings unrelated to the change into the gate's report, so the gate would be judging code the change never touched, and the report would not answer "is this change safe?"
- **Diff-scoped scan via the skill's own path-scope feature.** Chosen — the skill already accepts a scope argument; the reviewer derives the scope from the fixed point it already holds. The deviation from the skill's default is deliberate and recorded here.
- **A separate `security-reviewer` role.** Rejected — `security-review` is a single-agent workflow (it spawns no subagents), so a separate role would add a second role to keep in sync with the reviewer for no isolation gain.
- **Merged into the existing reviewer.** Chosen — one host, one gate, one dispatch surface; the reviewer's edit-tool-free contract already covers the security path.

## Consequences

- **Positive**: Security properties of the change are reviewed before close, in both flows — one gate, one dispatch, no new role.
- **Positive**: The report answers "is this change safe?" — findings are scoped to the change, not the project.
- **Positive**: The skill stays vendored-unedited; upstream provenance is preserved and re-imports stay byte-comparable.
- **Negative**: A cleared session between code-review and security-review re-lands in the "Every AC box checked" state and re-runs code-review. Accepted — the review is read-only and idempotent; the cost is one redundant run.
- **Neutral**: The skill is interactive-framed ("requires human approval," "propose patches"). In the subagent context the patch proposals become report text; the director's fix workers (director flow) or the user (implementer flow) apply them. No skill change needed.
