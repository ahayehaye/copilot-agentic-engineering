# Day-to-day workflows

Standing workflows for this workspace. You talk to the agent; the skills do
the mechanics — number claiming, INDEX updates, ticket bodies. The tracker
doc (`docs/agents/issue-tracker.md`) is the authority on ticket structure;
this page is the shape of the conversation.

## Worked example 1 — a light ticket

A small, self-contained change: one file, one sitting, no follow-up. No
vertical slices, no heavy acceptance criteria.

1. **Say what you want.** "Fix the typo in the README." Trivial — no scoping
   skill needed.
2. **Publish the spec.** The agent names `/to-spec`; you invoke it. The
   skill claims the next number in `engineering/`, writes the ticket, and
   updates the INDEX. The spec carries a minimal acceptance criterion — "the
   README reads correctly and nothing else changed."
3. **No slices.** You say "no slices needed." (You can always cut them later
   with `/to-tickets` if the work turns out to be bigger.)
4. **Implement and verify.** `/implement` on the ticket does the edit;
   `/verify-ac` checks the AC against the live state and records it.
5. **Close out.** The agent prompts you: "worth recording?" —
   `/remember record fixed the README typo (engineering #4)`.

## Worked example 2 — a heavy ticket

Real work: spans files, spans sessions, needs a decision recorded.

1. **Scope it.** `/grill-with-docs` — stress-test the plan before it is
   written down. (`/grilling` and `/plan-from-docs` work too.) Decisions land
   here, not in the spec.
2. **Publish the spec.** `/to-spec` — the skill claims the number,
   writes the spec, and updates the INDEX. If the work spans an external
   system, the spec carries a `Refs:` line with namespaced IDs
   (e.g. `Refs: ado:12345`).
3. **Cut slices.** `/to-tickets` — vertical slices, each sized for one
   fresh context window, each with blocking edges.
4. **Implement.** `/implement <namespace> #N` — works the frontier (unblocked
   slices, first by number), checks AC boxes as each slice lands, commits to
   the branch.
5. **Verify.** `/verify-ac <namespace> #N` — validates every slice's ACs against
   live repository state and records the verified state.
6. **Close out.** The agent prompts you to record the decision —
   `/remember record ...`.

## Standing workflows

### Resume after a cleared session

Reconstruct from the tracker and git, in this order:

1. `git branch --show-current` and `git status` — where is the work?
2. The ticket's INDEX status and AC boxes — what is done, what remains?
3. Name the next step from that state: resume `/implement`, run
   `/verify-ac`, or close out.

### Record and recall memory

- **Record:** `/remember record <details>` — one dated, typed entry
  (event or state) plus an index update.
- **Recall:** `/remember <question>` — index-first lookup, answered
  from matching entries.
- **Current truth:** states with the same `key` supersede each other; the
  active state is the current truth.

### Write a research entry

A cited, sourced, dated entry in `research/` (see `research/README.md`).
Ticket-driven investigations live in `tickets/research/`; the entry is their
evidence. The two partitions are distinct — never conflate them.

### Add a namespace

Tell the agent: "add an `ops` namespace." It creates `tickets/ops/` with its
`INDEX.md` and its own number space — a direct, user-instructed action, no
ticket. New namespaces are user content; the ledger manager never touches
them.

### Link an external tracker

A ticket that spans an external system carries a `Refs:` line with namespaced
IDs (`ado:12345`, `gh:owner/repo#678`). The external tracker is the source of
truth for status; the local INDEX status is the local working view. A
mismatch is reported, not reconciled.

### Scaffolding drift

When the source repo's scaffolding changes, `ledger-manager.sh upgrade
<this-dir>` reports drifted manifest files with a diff and never overwrites
them. Adopt a drifted file deliberately: `--reinstall` (timestamped backup,
then replace). Your content is never touched.
