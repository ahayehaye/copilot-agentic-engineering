# Workspace

A local ticketing + research + memory workspace for software and systems work.
Deployed by the Ticket Ledger manager; the source repo is the source, this
workspace is a generated artifact. Never edit scaffolding here — edit the
source repo and re-run `ledger-manager.sh upgrade`.

## Agent skills

### Issue tracker

Tickets live as local markdown under `tickets/`. See
`docs/agents/issue-tracker.md`. Tickets that span external systems carry a
`Refs:` line (namespaced IDs, e.g. `ado:12345`) — see the tracker doc.

New here? Start with `docs/getting-started.md`; day-to-day sequences are in
`docs/workflows.md`.

<!-- setup-alex-skills:label-rule -->
**Label rule (overrides skill defaults):** when publishing via `/to-spec` or
`/to-tickets`, apply the label rule in `docs/agents/issue-tracker.md` — specs
get `spec`, slices get `vertical-slice`. The skills' default `ready-for-agent`
label may be added but never replaces them.
<!-- /setup-alex-skills:label-rule -->

### Domain docs

Single-context workspace — one `CONTEXT.md` and `docs/adr/` at the root. See
`docs/agents/domain.md`.

## Testing

- Do not write tests for bash scripts, anywhere in this workspace.
- When doing potentially risky or dangerous actions with the shell, always
  consult the shell-safety skill.
- **Do not attempt fixture dry-runs for bash scripts** (temporary HOME, stubbed
  binaries, fake PATH). These are unreliable in agent execution. Verify bash
  scripts with `bash -n` (syntax), `bash -x` (trace on the real machine), and
  live acceptance runs instead.

## Content constraints (third rails)

This workspace is strictly work. In all authored content — tickets, research,
memory, skills, docs:

1. No personalization with names.
2. No references to crew or creative writing.
3. No tokens burned on social niceties, personas, or similar.
