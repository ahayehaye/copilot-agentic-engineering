---
name: verify-ac
description: Verify a ticket's acceptance criteria inline against live repository state and record the verified state on the tracker. Accepts a parent ticket (discovers and verifies every slice, parent summary on all-pass) or a single slice ticket (verifies that one ticket only). Use after /implement completes with unverified slices, or on re-entry with unchecked AC boxes.
version: 1.2.0
---

# verify-ac

Input: a ticket number, nothing else — `/verify-ac #<ticket>`. Two input forms, disambiguated by an explicit rule:

1. Fetch the input ticket first.
2. Its body carries an "Acceptance criteria" checklist → **slice mode**: verify that one ticket.
3. Otherwise → **parent mode**: discover its slices and verify them all.

No override flag: a misclassification lands on the safe hard-stop (empty discovery), never on a wrong write. This matches the repo's ticket convention — specs carry no AC boxes; slices do.

Every tracker operation in this protocol — ticket fetch, slice discovery, comment posting, box-checking, parent summary — is an operation defined by the project's issue-tracker doc at `docs/agents/issue-tracker.md`, read at run time. The protocol names no tracker command as a requirement; the concrete commands come from that doc.

## Parent mode

### 1. Discover the slices (strict union)

Run **all** slice-discovery mechanisms the issue-tracker doc defines and take the union, deduplicated, in number order. There is no generic fallback in this skill: a tracker doc that defines no discovery mechanisms yields the empty union.

A parent with no discoverable slices is a contradiction to surface, not an empty success: stop and report it, verify nothing (not against the spec), record nothing, and wait for user direction. If the input ticket was classified as parent because it carries no "Acceptance criteria" checklist, the report adds a line noting the input ticket may be a malformed slice.

### 2. Per slice: validate the ACs

For each slice in the union, in number order:

- Fetch the ticket. Read the "Acceptance criteria" list **verbatim** from the ticket body — the ticket is the source of truth, never the session context.
- For each AC, in ticket order, run its check against **live repository state**: read the files, run the commands, diff the deployed targets. An AC passes only on observed evidence. Do not assume.

### 3. Per slice: record the result

- Post one per-AC comment on the slice: one line per AC in ticket order, each carrying a one-line evidence or observation. The format is loose and owned by this skill — the comment is a human-readable record, never parsed by the state machine.
- If **every** AC in the slice passes: check the slice's AC checkboxes in the ticket body (`- [ ]` → `- [x]`).
- If any AC fails: leave the boxes unchecked and report the failure in-session.

### 4. Parent summary

Only when **every slice passes**: post one summary comment on the parent — the slice count and the commit under test (`git rev-parse HEAD`). On any failure: no parent summary; the failed ACs are already reported in-session.

## Slice mode

Run parent mode step 2 on the one ticket, then record the result exactly as in parent mode step 3: one per-AC comment; on all-pass, check the boxes; on any failure, leave the boxes unchecked and report in-session. No discovery, no parent summary — the parent summary is a parent-run artifact.

## Re-runs

Safe by construction: checking an already-checked box is a no-op, and comments are append-only. A partial or stale run can simply be re-run.

## Tracker binding: GitHub (example)

A documented example of one binding — the concrete `gh` commands for a project whose issue-tracker doc is GitHub. Adding another binding (GitLab, local markdown, ...) means appending a section, not editing the protocol.

- **Discover the slices** — the three mechanisms below; run all of them and combine the results per the protocol's union rule:
  - Sub-issues endpoint: `gh api repos/<owner>/<repo>/issues/<parent>/sub_issues`. A 404 or empty result is fine — the other mechanisms still run.
  - Body search 1: `gh issue list --state open --json number,title,body --jq '[.[] | select(.body | contains("Part of #<parent>")) | .number]'`.
  - Body search 2: a body search for the `## Parent` section format — a `## Parent` heading line, one or more whitespace lines, then a line that is exactly `#<parent>`: `gh issue list --state open --json number,title,body --jq '[.[] | select(.body | test("(?m)^## Parent\\s*\\n+\\s*#<parent>\\s*$")) | .number]'`.
  - The body searches keep their open-state filter.
- **Fetch a ticket**: `gh issue view <n> --comments` — the doc's read convention; the body in the output is the ticket's source of truth.
- **Post a comment** (per-AC comment or parent summary): `gh issue comment <n> --body "..."`.
- **Check the boxes**: replace `- [ ]` with `- [x]` in the ticket body and PATCH it via `gh api -X PATCH --input body.json` (never `gh api -f body=`).
