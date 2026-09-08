---
name: verify-ac
description: Verify a parent ticket's slice acceptance criteria inline against live repository state and record the verified state on the tracker. Use after /implement completes with unverified slices, or on re-entry with unchecked AC boxes.
version: 1.1.1
---

# verify-ac

Input: the parent ticket number, nothing else — `/verify-ac #<parent>`. Never take slice numbers; discover them.

## 1. Discover the slices (union)

Run all three discovery mechanisms and take the union, deduplicated, in number order:

- Sub-issues endpoint: `gh api repos/<owner>/<repo>/issues/<parent>/sub_issues`. A 404 or empty result is fine — the other mechanisms still run.
- Body search 1: `gh issue list --state open --json number,title,body --jq '[.[] | select(.body | contains("Part of #<parent>")) | .number]'`.
- Body search 2: a body search for the `## Parent` section format — a `## Parent` heading line, one or more whitespace lines, then a line that is exactly `#<parent>`: `gh issue list --state open --json number,title,body --jq '[.[] | select(.body | test("(?m)^## Parent\\s*\\n+\\s*#<parent>\\s*$")) | .number]'`.

The body searches keep their open-state filter. A parent with no discoverable slices is a contradiction to surface, not an empty success: stop and report it, verify nothing (not against the spec), record nothing, and wait for user direction.

## 2. Per slice: validate the ACs

For each slice in the union, in number order:

- Fetch the ticket: `gh issue view <n> --json body --jq .body`. Read the "Acceptance criteria" list **verbatim** from the ticket body — the ticket is the source of truth, never the session context.
- For each AC, in ticket order, run its check against **live repository state**: read the files, run the commands, diff the deployed targets. An AC passes only on observed evidence. Do not assume.

## 3. Per slice: record the result

- Post one per-AC comment on the slice: one line per AC in ticket order, each carrying a one-line evidence or observation. The format is loose and owned by this skill — the comment is a human-readable record, never parsed by the state machine.
- If **every** AC in the slice passes: check the slice's AC checkboxes in the ticket body (`- [ ]` → `- [x]`) via `gh api -X PATCH --input body.json` (never `gh api -f body=`).
- If any AC fails: leave the boxes unchecked and report the failure in-session.

## 4. Parent summary

Only when **every slice passes**: post one summary comment on the parent — the slice count and the commit under test (`git rev-parse HEAD`). On any failure: no parent summary; the failed ACs are already reported in-session.

## Re-runs

Safe by construction: checking an already-checked box is a no-op, and comments are append-only. A partial or stale run can simply be re-run.
