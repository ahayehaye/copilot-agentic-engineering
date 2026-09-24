# Issue tracker: Local Markdown

Tickets for this workspace live as markdown files under `tickets/`, in two
namespaces: `tickets/engineering/` (system changes) and `tickets/research/`
(ticket-driven investigations).

## Directory structure

```
tickets/
  engineering/
    INDEX.md
    00001-<feature-slug>/
      spec.md
      slice-01-<slug>.md
      slice-02-<slug>.md
  research/
    INDEX.md
    00001-<investigation-slug>/
      spec.md
      slice-01-<slug>.md
```

## Vocabulary

- A **parent ticket** is a `NNNNN-<slug>/` directory; its body is `spec.md`.
- A **slice** is a child ticket, filed as `slice-NN-<slug>.md` in the parent
  directory.
- A **semantic ticket** is a parent ticket that concentrates an effort
  spanning external systems; its spec carries a `Refs:` line (see below).

## Conventions

- **Number spaces are per-namespace.** `tickets/engineering/00001` and
  `tickets/research/00001` are distinct tickets. The next number is the
  highest existing prefix in *that namespace* plus one, zero-padded to
  **five digits** (NNNNN, supporting 99999 tickets).
- **Slice numbers are two digits** (NN, max 99 per parent).
- **Numbers are never reused.** Abandoned tickets leave burned numbers; gaps
  are fine.
- **Slugs are immutable** once created. Charset: lowercase letters, digits,
  hyphens; max 40 characters; no trailing hyphen.
- **The INDEX is load-bearing.** Each namespace has an `INDEX.md`
  (number → slug → status). Every ticket creation and status change updates
  it. Status vocabulary: `active / paused / done / abandoned`.
- **Create directories with plain `mkdir`** (not `mkdir -p`) when claiming a
  new number: if the directory exists, the command fails and you pick the
  next number. Never write into an existing number directory.
- Comments and conversation history append to the bottom of the file under a
  `## Comments` heading.
- **Adding a namespace.** A new namespace is a new directory under `tickets/`
  plus its own `INDEX.md` and its own number space (e.g. `tickets/ops/`).
  New namespaces are user content; the ledger manager never touches them.

## Ticket reference shorthand

Ticket references may be given as `<namespace> #NNNNN` (e.g. `engineering #1`,
`research #3`) or `<namespace>/NNNNN`. The namespace is **required** — a bare
`#1` is ambiguous across number spaces and must be refused, not guessed.
Resolve via the namespace's `INDEX.md`: number → slug → full path. Parent
shorthand resolves to the ticket directory. Slices are referenced by number
(`slice 3`) or by filename (`slice-03-<slug>.md`); both resolve within the
parent directory. Slice numbers are unique within a parent, so `slice N` is
unambiguous — resolve by matching `slice-NN-*` (zero-pad N to two digits).
Exactly one match is expected: zero → report not found and list the parent's
slices; more than one → list them and don't guess. If the parent number is
not in the index, report it and list the index contents — never guess a slug.

## `Refs:` convention

### When to use

Add a `Refs:` line when the ticket **spans an external system** — its status
lives in ADO or GitHub, or it concentrates an effort tracked elsewhere. If
the work is entirely local, omit the line. When in doubt, add it: a `Refs:`
line costs nothing, and a missing link is harder to reconstruct.

### Format

A spec (and optionally a slice) may carry a `Refs:` line with namespaced
external IDs:

```
Refs: ado:12345
Refs: gh:owner/repo#678
```

- The **namespace prefix is required** (`ado:`, `gh:`, …) — a bare number is
  ambiguous across trackers.
- Multiple `Refs:` lines are allowed.
- The **external tracker is the source of truth for status**; the local INDEX
  status is the local working view. A mismatch is reported, not reconciled.
- `verify-ac` does not check external status — verification stays local.
  External checks are a separate, explicit action via `ado-boards`.

## `Blocked by:` graph

A `Blocked by: NNNNN, NNNNN` line near the top of a ticket body records the
parent tickets (in the same namespace) that must be done before this one can
start. A ticket is unblocked when every listed ticket's INDEX status is
done. The frontier is the set of open, unblocked tickets; first by number
wins.

## Research namespace vs research library

Two distinct partitions, never conflated:

- **`tickets/research/`** — the ticket namespace for ticket-driven
  investigations ("Investigate the implications of XYZ"). The ticket is the
  work; the research entry is its evidence.
- **`research/`** — the research library: cited, sourced, dated, living
  entries (see `research/README.md`).

## When a skill says "publish to the issue tracker"

Create a new parent directory under the appropriate namespace (using the next
available number in that namespace, plain `mkdir`) and its contents inside,
then update the namespace `INDEX.md`.

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path,
a shorthand reference, or the number directly.

## Slice discovery

Used by `verify-ac` (parent mode) and `/implement`. The mechanisms any
workflow consumes to find a parent's vertical slices, taken as a **strict
union** (deduplicated, in number order):

1. **The slice files themselves.** Every `slice-NN-<slug>.md` file in the
   parent ticket's directory is a slice.
2. **The `## Parent` section.** A slice body that carries a `## Parent`
   heading followed (after one or more blank lines) by a line that is exactly
   `#<parent-number>` is a slice of that parent.
3. **The `Part of #<parent>` line.** A slice body whose top section contains
   the line `Part of #<parent>` is a slice of that parent.

A parent with no discoverable slices is a contradiction — report it; do not
guess.

## Body edit

In-place file edit. A slice body is edited directly in its
`slice-NN-<slug>.md` file. Checking an AC box, appending a `## Comments`
entry, or changing a status line is a direct edit of that file. A status
change additionally updates the namespace `INDEX.md` in the same step.

## Ticket labels

This tracker is local markdown: labels are recorded as a `Labels:` line near
the top of the ticket body (e.g. `Labels: spec`, `Labels: vertical-slice`).
The standard taxonomy is exactly two labels:

- `spec` — a parent ticket published by `/to-spec`.
- `vertical-slice` — a slice published by `/to-tickets`.

**Label-application rule:** a spec published by `/to-spec` is created
with the `spec` label; a slice published by `/to-tickets` is created
with the `vertical-slice` label. This rule takes precedence over any skill
instruction to apply a different default label, for example
`ready-for-agent` (which may be added but never replaces them).
