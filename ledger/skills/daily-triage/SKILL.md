---
name: daily-triage
description: Surface the day's shape from the ticket-ledger — a scannable, non-ranked view of active tickets and open stubs across all namespaces, a deferred rollup, and one named next step. Use at the start of the day (or on demand) to collapse the open-ticket pile into a fast now/defer call. Distinct from the `triage` skill (a code/issue state machine).
version: 1.0.0
---

# daily-triage

One deliberate check that collapses the day into a scannable shape. The session
*is* the notification — it replaces a dozen "what's next?" pings. It does not
rank; it surfaces candidates and supports a fast now/defer call. Importance is
time-relative: what matters *at that point in time*.

This is not the `triage` skill. `triage` moves a single issue through a state
machine of triage roles; `daily-triage` surveys the whole ledger and names the
day's shape.

## The session

Work the steps in order. The sweep is deterministic; the surfacing is judgment.

### 1. Sweep (read-only)

Gather, in this order:

- **The ticket-ledger.** Discover the namespaces: every `tickets/<namespace>/`
  directory with an `INDEX.md` (number → slug → status). The ledger seeds
  `engineering`, `research`, and `stubs`, but more are user content and the
  sweep covers all of them — a missing seeded namespace (user content may be
  deleted) is handled gracefully, not an error. For each namespace, read the
  INDEX plus each actionable item's AC boxes and `Blocked by:` lines. Surface
  the `active` tickets — noting which are blocked (a `Blocked by:` edge) and
  which are ready to move (blockers cleared) — and any `open` stubs (a
  pre-commitment home for real work whose shape isn't known yet; a stub's done
  is a decision — promote / cancel / resolve — not a completion). A `paused`
  ticket is parked: one carrying a `Deferred until:` line goes in the deferred
  rollup; one without it is surfaced in its namespace section, marked parked.
- **External refs.** For tickets carrying a `Refs:` line (`ado:12345`,
  `gh:owner/repo#678`), the external tracker is the source of truth for status.
  Check `docs/agents/issue-tracker.md` for how to access the ticketing systems
  in this environment; ADO work items are checked via the `ado-boards` skill,
  when the day's shape depends on them. Surface a mismatch between the local
  INDEX and the external state; do not reconcile it.
- **Git.** `git branch --show-current`, `git status` — clean or mid-change?
- **The previous record.** Read the most recent record in
  `reports/daily-triage/` if any — it is the trend baseline for the Level line
  and the source of carried `Last Update` dates. First run (no previous
  record): trend is `n/a (first run)`, every `Last Update` is today, and the
  worksheet (`triage/`) and record (`reports/daily-triage/`) directories are
  created.

Every tracker operation in this protocol — reading the INDEX, fetching a
ticket, discovering slices — is an operation defined by the project's
issue-tracker doc at `docs/agents/issue-tracker.md`, read at run time. The
protocol names no tracker command as a requirement; the concrete commands come
from that doc.

Every ticket reference uses the namespace-required shorthand (e.g.
`engineering #12 add-foo`) — namespace + number + slug. A bare number is
ambiguous across number spaces and is not recognizable at a glance; the
namespace and the name are what make it so.

**Skip any item carrying a `Deferred until: <date>` line whose date is in the
future** — it re-enters on the date (the line stays as provenance); collect the
skipped items for the deferred rollup (step 2).

### 2. Surface — the day's shape

Produce the day's shape in this shape:

```
# Triage — <Weekday>, <YYYY-MM-DD>

*Scan, not ceremony. Non-ranked. The session is the notification; the shape is
what you work on.*

**Level:** <N> open items (tickets + stubs) (<trend vs last run>). <one line
on the level — holding / trending down / up>.

## Deferred (the horizon)

<N> total — what's parked and when it re-enters. Early warning, not a to-do.
- <slug> — <date>
- … (up to 10, next-due first)
- (+<M> more)   ← only if over 10

## <namespace>            ← one section per discovered namespace (empty ones omitted)
- **<bold lead>** — <what it is, its state, why it's here>
    - **Last Update**: <YYYY-MM-DD>
    - **The read**: <a one-line lean on do/defer/kill — the prompt, not the decision>
    - **UPDATES**:

## <next namespace>
- …

## Next step

`<exactly one command>` — <one line on why this is the one>

## New since the sweep

- (anything that came up after the sweep — the user adds these)
```

Rules that make it a scan, not a wall of text:

- **Blank line between list items.** Any list item that carries a multi-line
  body gets a full blank line before the next item; a section header gets a
  blank line before its first line of content.
- **Per-namespace sections** — one `## <namespace>` section per discovered
  namespace — each a flat bullet list. No sub-headers, no ranking, no priority
  sort. An empty namespace (no surfaced items) is omitted from the shape.
- **Bold leads on every actionable item** — the ticket name. The bold is the
  thing the eye lands on; the rest is context.
- **One ID, one item — no piles.** A ticket that carries its own number gets
  its own bullet with its own bold lead, `Last Update`, `The read`, and
  `UPDATES`. Never compress several numbered items into a single pile — a pile
  gets deferred as a lump; the split forces a decision on each item.
- **The read + UPDATES under each actionable item** — the lean (one line, the
  prompt not the decision; the user overrides it freely) and a blank line for
  the user to fill in. A blank UPDATES, or "thinking about this, no decision,"
  is a complete answer, not a form to finish.
- **The Last Update line.** Each item carries a `**Last Update**: <YYYY-MM-DD>`
  line — the first sub-bullet, before `The read`. It is the date the item's
  disposition was last recorded. Carry it forward from the previous report: an
  item the user touches today gets today's date; one the user doesn't keeps its
  last date, so a skipped day is a visible gap — the gap itself tells you how
  long the item has been sitting.
- **The Level line** — the count of open items, the trend vs the last report,
  and one line on the level. The count is defined: every ticket whose status
  is not `done`/`abandoned` (active, paused, and open stubs), minus deferred
  items (which live in the Deferred rollup). This is the number this routine
  is trying to hold at a level.
- **One named next step** — exactly one command, in backticks, with a one-line
  why. Not a list of options. If there are two live doors, name the lean and let
  the user redirect.
- **The deferred section (`## Deferred`).** Items carrying a `Deferred until:
  <date>` line (date in the future) are excluded from the namespace view; the
  section names the **total count** plus a **list of up to 10** deferred items
  (slug + date, sorted next-due first). If more than 10, show the total + the
  next 10 + "+N more". It's an **early-warning system for what's on the
  horizon** — the parked things, and when they re-enter — not a to-do list.
  Fully invisible is the failure mode.
- **Surface neglect plainly, never as a deficit count.** A thing that has been
  sitting is useful to name; the moment it becomes a *score* of how much is
  being lost, it flips from manageable to aversive. Name it, don't tally it.

### 3. (Optional) Two-pass delivery

The do/defer/kill can be a **two-pass worksheet**, so the user can sit with the
day's list as a focused activity in their editor instead of scrolling the
terminal. There are two files in separate directories: the **worksheet** (the
raw working copy the user fills in) and the **record** (the official, committed
report). Keeping them apart means the working copy is never mistaken for the
record.

1. **Write the worksheet.** The day's shape (from step 2), with `The read` and a
   blank `UPDATES` line under each actionable item, plus the `## New since the
   sweep` section, to `triage/<YYYY-MM-DD>.md`.
2. **The user fills it in, async.** At their pace, as the day unfolds — notes
   on why something's stuck, the next step, why it's no longer needed, or a new
   item under `## New since the sweep`.
3. **Once the user returns it, process.** The user says they've updated it.
   Read the worksheet, **transcribe their UPDATES verbatim** (not summarized)
   into the record, act on them (do/defer/kill, file the ticket), and write a
   `DECISION` line under each. A deferral is a legitimate outcome, not a
   failure. **A deferral is acted on by writing the `Deferred until: <date>`
   line into the ticket's header** — the user's natural language ("defer two
   weeks") resolved to a concrete date (grounded in `date`, not narrated); the
   `DECISION` line records the resolved date so the user can adjust.

### 4. The record

The session always leaves a record, on both delivery paths:

- **Two-pass used.** On hand-back, write the record to
  `reports/daily-triage/<YYYY-MM-DD>.md`, *derived from* the worksheet, so the
  two don't drift into parallel records: the day's shape + the user's UPDATES
  verbatim + the `DECISION` lines. The worksheet at `triage/<YYYY-MM-DD>.md`
  is the raw working copy and stays as long as the user wants it.
- **Two-pass skipped.** At session end, write the record directly from the
  shape — no worksheet is created.

The record is the **official record**. The principle is to keep the raw
material, not a quantized summary — the more of the "how we got here" that's
kept, the more it's worth later. The skill writes the file and never commits;
the record is committed by the user at their pace.

## The namespace view

Triage operates at the **namespace** level, not the individual-ticket level.
The namespaces are the unit of attention — you triage the namespace, not a
single fragment. A concern belongs to the namespace of
where it *lands*, not where it comes from. The namespace is a **view, not a
storage location** — no migration, no re-filing. Tickets stay where they are;
the namespace is how they are *grouped* at triage time.

## Boundaries

Read-only over the tracker and git. It names the next command; the user invokes
it. It never implements, never checks AC boxes, never closes a ticket. The
by-hand cleanup is the user's, at their pace; this skill *consumes* that
cleanup, it does not perform it.

## Principles

- **Scan, not ceremony.** Short, scannable, groups what belongs together. It
  doesn't rank — it surfaces candidates and supports a fast now/defer call.
- **Neglect is information, not a scoreboard.** Surface the sitting-things
  plainly; never as a deficit count.
- **Delivery is the anchor; content is debatable.** The two-pass worksheet and
  the report shape are fixed; what's surfaced is tuned in use.
- **Gardening, not a project.** The pile regrows as new tickets are created.
  The goal is not zero — it is to maintain the pile at a level.
