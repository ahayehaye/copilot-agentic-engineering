# Getting started

This workspace is a local ticketing + research + memory environment. It is a
generated artifact: the source repo is the scaffolding, this workspace is the
content. Never edit scaffolding here — edit the source repo and re-run
`ledger-manager.sh upgrade`.

## First run

1. Deploy (once, from the source repo): `ledger-manager.sh deploy <this-dir>`.
   The workspace is a local git repository with an initial commit — the
   backstop for every file you add.
2. Open a session in this directory. `AGENTS.md` and the docs under
   `docs/agents/` carry the conventions; this page is the map.
3. Commit your work at your own cadence. The manager never commits for you.

## The shape of the workspace

| Partition | What it holds |
|-----------|--------------|
| `tickets/` | Work, in namespaces. `engineering/` (system changes) and `research/` (ticket-driven investigations) are seeded. Each namespace has an `INDEX.md` (number → slug → status) and its own number space. |
| `memories/` | Dated, typed entries — events (milestones) and states (current truths). The index (`memories/index.md`) is the read-first entry point. Managed by the `remember` skill. |
| `research/` | The research library: cited, sourced, dated, living entries. Distinct from the `research` ticket namespace. |

## Light work vs real work

Before any ticket work, establish the scope of what you want to do:

- **Scope it first.** Use `/grill-with-docs` to make sure the scope of your
  ticket is understood and explored. `/grilling` and `/plan-from-docs` work
  too. For trivial work, free-form is fine — just say what you want.
- **Light work** — a small, self-contained change: touches one file, done in
  one sitting, no follow-up. No vertical slices needed (you can always ask
  for slices later). The skills handle the ticket; you handle the review.
- **Real work** — spans files, spans sessions, or needs a decision recorded.
  Go through the full workflow: scope, publish a spec, cut slices, implement,
  verify. See `docs/workflows.md` for the full sequence and two worked
  examples.

The rule of thumb: **touches more than one file, or spans sessions → real
work.** When in doubt, scope it — the cost of a light ticket is low, and the
cost of an unrecorded decision is higher.

## Your first ticket

You do not claim numbers or edit INDEX files by hand — the skills do that.
The flow is a conversation:

1. **Say what you want to build.** The agent (see the `ticket-ledger` agent)
   will encourage you to scope it first: `/grill-with-docs` (recommended),
   `/grilling`, or `/plan-from-docs`. Trivial work can skip straight to the
   spec.
2. **Publish the spec.** `/to-spec` — the skill claims the next number
   in the right namespace, writes the ticket, and updates the INDEX.
3. **Slices, if needed.** For real work, `/to-tickets` cuts vertical
   slices. For light work, say "no slices needed" — you can always cut them
   later.
4. **Implement and verify.** `/implement <namespace> #N` works the slices (or the
   light ticket directly); `/verify-ac <namespace> #N` validates the acceptance
   criteria against the live state.
5. **Close out.** The agent prompts you to record what is worth remembering —
   `/remember record ...`.

The tracker doc (`docs/agents/issue-tracker.md`) is the authority on all of
this — numbering, slugs, status vocabulary, `Blocked by:` graphs, labels.

## Adding a namespace

Tell the agent: "add an `ops` namespace." It creates
`tickets/ops/` with its `INDEX.md` and its own number space — a direct,
user-instructed action. No ticket needed: a namespace is scaffolding, not
work. New namespaces are user content; the ledger manager never touches them.
