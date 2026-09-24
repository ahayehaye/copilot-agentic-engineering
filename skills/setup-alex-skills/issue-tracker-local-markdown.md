## Slice discovery

Used by any workflow that needs a parent's vertical slices — `verify-ac`
(parent mode) and `/implement` (dependency graph). Run **all three**
mechanisms below and take the union, deduplicated,
in number order — the strict-union rule is the consumer's; the priority
order below is readability only. A missing mechanism is fine — the other
mechanisms still run.

1. **The slice files themselves.** Every `slice-NN-<slug>.md` file in the
   parent ticket's directory is a slice:
   `ls tickets/<namespace>/NNNNN-<slug>/slice-*.md`
2. **The `## Parent` section.** A slice body that carries a `## Parent`
   heading followed (after one or more blank lines) by a line that is exactly
   `#<parent-number>`:
   `grep -rlEz '(?m)^## Parent\s*\n+\s*#<parent>\s*$' tickets/`
3. **The `Part of #<parent>` line.** A slice body whose top section contains
   the line `Part of #<parent>`:
   `grep -rlE 'Part of #<parent>' tickets/`

A parent with no discoverable slices is a contradiction — report it; do not
guess.

## `Blocked by:` graph

A `Blocked by: NNNNN, NNNNN` line near the top of a ticket body records the
parent tickets (in the same namespace) that must be done before this one can
start. A ticket is unblocked when every listed ticket's INDEX status is
done. The frontier is the set of open, unblocked tickets; first by number
wins.

## Body edit

Used to edit a ticket body in place (e.g., checking AC boxes: `- [ ]` →
`- [x]`).

Edit the file directly: `tickets/<namespace>/NNNNN-<slug>/spec.md` or
`tickets/<namespace>/NNNNN-<slug>/slice-NN-<slug>.md`. A status change
additionally updates the namespace `INDEX.md` in the same step.

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
