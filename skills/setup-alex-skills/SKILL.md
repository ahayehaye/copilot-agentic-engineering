---
name: setup-alex-skills
description: "Enhances a repo already set up by /setup-matt-pocock-skills so the tracker-dependent workflow skills (notably verify-ac) work fully: adds slice discovery, body edit, and the standard label taxonomy to the GitHub-flavored tracker doc, creates the standard labels on the tracker, and enforces the label rule over the skills' ready-for-agent default with a marker-wrapped label-rule block in the target file (AGENTS.md or CLAUDE.md). Run after /setup-matt-pocock-skills; v1 supports the GitHub flavor only."
version: 1.2.0
---

# Setup Alex Skills

Enhance a repo already set up by `/setup-matt-pocock-skills` so the tracker-dependent workflow skills (notably `verify-ac`) work fully. The enhancement is additive: it adds the operations the upstream tracker templates leave out — slice discovery, body edit, and the standard label taxonomy — to the repo's tracker doc (`docs/agents/issue-tracker.md`), in the flavor's own concrete commands, it creates the standard labels on the tracker, and it writes a label-rule block into `AGENTS.md` (or `CLAUDE.md`) that enforces the label taxonomy over the skills' `ready-for-agent` default.

This is a prompt-driven skill, not a deterministic script. Run the gates, explore, present what you found, confirm with the user, then write.

## Gates

Both gates run before exploration. If either gate fails, stop: no exploration, no draft, no writes.

### Gate 1: Precondition — the upstream setup must have run

Check both:

1. `docs/agents/issue-tracker.md` exists.
2. `AGENTS.md` or `CLAUDE.md` at the repo root contains an `## Agent skills` block (the upstream setup writes it).

Note which file holds the block — `AGENTS.md` or `CLAUDE.md`. That file is the **target file** for the label-rule block enhancement.

If either is missing, stop and say:

> `/setup-alex-skills` needs the upstream setup first. Run `/setup-matt-pocock-skills` in this repo, then re-run `/setup-alex-skills`.

This is a hard stop, not a suggestion: do not create the tracker doc or the `## Agent skills` block yourself.

### Gate 2: Flavor — v1 supports GitHub only

Detect the tracker flavor from `docs/agents/issue-tracker.md`:

- The upstream templates title the doc `# Issue tracker: <Flavor>` — read that title first.
- If the doc has no such title (an "other" tracker written freeform), classify by its conventions: `gh` CLI → GitHub, `glab` CLI → GitLab, markdown files under `.scratch/` → local markdown, anything else → other.

If the flavor is **GitHub**, continue — the seed for the GitHub flavor is the template files `issue-tracker-github.md` and `agents-md-github.md` in this skill's directory (see [Seed: the GitHub enhancement](#seed-the-github-enhancement) below). Otherwise, stop and say:

> `/setup-alex-skills` v1 supports the GitHub flavor only. This repo's tracker is <flavor>. Azure DevOps support is tracked upstream; GitLab and local markdown are future flavors.

No partial writes: do not draft or write any part of the enhancement for an unsupported flavor.

## Process

### 1. Explore

- Read `docs/agents/issue-tracker.md` in full — every section.
- For each of the four enhancements (slice discovery, body edit, label taxonomy, target-file label rule), check the target surface: present? missing? present but drifted (user edits)?
- For the label-rule block, check the target file: is there a block between the `<!-- setup-alex-skills:label-rule -->` and `<!-- /setup-alex-skills:label-rule -->` markers, and does it match the template [agents-md-github.md](./agents-md-github.md)? Also check for legacy `<!-- alex-skills:label-rule -->` / `<!-- /alex-skills:label-rule -->` markers (pre-1.2.0 installs) — their presence is a migration case, not a missing block.
- Check the tracker's label state: `gh label list --json name,description` — do `spec` and `vertical-slice` exist, and with what descriptions?

### 2. Present findings and ask

Summarize what's present and what's missing — one line per enhancement (including the label-rule block in the target file) and one line per standard label (exists / missing / description mismatch).

If every enhancement is present and unmodified and both labels exist with the canonical descriptions, the repo is already enhanced: report that the re-run is a no-op and stop.

Otherwise, build the delta: diff the existing doc against the enhanced form (the `issue-tracker-github.md` template, adapted to this repo), and diff the target file against the form with the label-rule block in place. The delta is additive only — the upstream sections (conventions, PR-surface flag, wayfinding, everything the upstream setup wrote) are preserved untouched. The user's hand edits to existing sections are preserved: the delta fills only the gaps — missing sections are added, drifted sections (and a drifted label-rule block) are presented side by side so the user decides, and nothing is silently clobbered.

### 3. Confirm and edit

Show the user a draft of:

- The enhanced `docs/agents/issue-tracker.md` — the full file, so the upstream sections are visibly preserved and the new sections are in place
- The label-rule block for the target file (`AGENTS.md` or `CLAUDE.md`) — the block from [agents-md-github.md](./agents-md-github.md), shown in its placement: inside the `### Issue tracker` subsection of the `## Agent skills` block (the subsection is added if missing)
- The label actions: create each missing label with its canonical description; leave existing labels as-is, flagging any description mismatch

Let them edit before writing.

### 4. Write

- Write the enhanced `docs/agents/issue-tracker.md`.
- Edit the target file idempotently: if the marked block (`<!-- setup-alex-skills:label-rule -->` … `<!-- /setup-alex-skills:label-rule -->`) is present, replace it in place with the block from [agents-md-github.md](./agents-md-github.md); if absent, insert it inside the `### Issue tracker` subsection of the `## Agent skills` block, adding the subsection when missing. Touch nothing else in the file.
- Migrate legacy markers: if the target file carries the legacy `<!-- alex-skills:label-rule -->` / `<!-- /alex-skills:label-rule -->` markers, replace them in place with the `setup-alex-skills:label-rule` markers — no fresh insertion, no orphaned block.
- Create the missing labels — only the missing ones (idempotent; never create a duplicate) — with the label-list and label-create command block in the "Ticket labels" section of the GitHub-flavor template, [issue-tracker-github.md](./issue-tracker-github.md), resolved relative to the skill's own directory (source dir or installed shared dir), per the [Seed: the GitHub enhancement](#seed-the-github-enhancement) section.

### 5. Done

Tell the user the enhancement is complete: which sections were added, which labels were created, where the label-rule block was written (which file, inserted or replaced in place), and that `verify-ac` and the other tracker-dependent workflow skills can now work fully. Mention that re-running this skill is safe (idempotent, drift-reconciling) and that the doc can be edited directly later.

## Seed: the GitHub enhancement

The three sections appended to the tracker doc (after the upstream sections, which stay untouched) are the GitHub-flavor template, [issue-tracker-github.md](./issue-tracker-github.md), in this skill's directory — the single source for the tracker-doc enhancement content. The label-rule block written into the target file is the template [agents-md-github.md](./agents-md-github.md), beside it — the single source for the AGENTS.md block content. Resolve the paths relative to the skill's own directory: the skill may run from the source dir (`skills/setup-alex-skills/`) or the installed shared dir (e.g., `~/.agents/skills/setup-alex-skills/`), and the templates sit beside the `SKILL.md` that was read. Adapt to the target repo: `<owner>/<repo>` from `git remote -v`. Triage labels remain the upstream setup's territory (`docs/agents/triage-labels.md`, where it wrote one); wayfinder labels remain in the wayfinding section — neither is part of the enhancement.
