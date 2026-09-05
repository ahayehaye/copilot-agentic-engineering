# Skills

## What it is

`skill-manager.sh` is the **Manager** for **Skills** — it installs, upgrades, and uninstalls them, moving items from the **Source** `skills/` directory to the **Target** `~/.agents/skills/` using the shared version-gated lifecycle. It is a thin wrapper that sources the [Shared Library](adr/0001-shared-manager-library.md); see the [glossary](../CONTEXT.md#glossary) for the full vocabulary (Skill, Source, Target, Version, Backup, Upgrade All).

## Install / upgrade / uninstall

Commands come from `bash scripts/skill-manager.sh --help`:

```
Usage: skill-manager.sh <command> [options] [args]

Commands:
  install <skill-name>          Install or upgrade a single skill
  install-all                   Install all skills from source
  upgrade <skill-name>          Alias for install <skill-name>
  upgrade-all                   Upgrade installed skills with newer source versions
  uninstall <skill-name>        Remove an installed skill
  list                          Show installed skills with versions
  list-available                Show skills available in source
  status                        Compare installed vs available (outdated/new)

Options:
  --reinstall, -f               Force reinstall even if version matches
  --dry-run, -n                 Preview changes without making them
  --source <path>               Override auto-detected skills/ directory
  --help, -h                    Show usage
```

Common flows:

```bash
bash scripts/skill-manager.sh install my-skill      # install, or upgrade if newer
bash scripts/skill-manager.sh install-all           # install every skill in source
bash scripts/skill-manager.sh upgrade my-skill      # alias for install my-skill
bash scripts/skill-manager.sh upgrade-all           # newer source versions only
bash scripts/skill-manager.sh uninstall my-skill    # remove an installed skill
bash scripts/skill-manager.sh list                  # installed skills + versions
bash scripts/skill-manager.sh list-available        # skills available in source
bash scripts/skill-manager.sh status                # installed vs available
```

Options:

```bash
bash scripts/skill-manager.sh install my-skill --dry-run    # preview, change nothing
bash scripts/skill-manager.sh install my-skill --reinstall  # force even if version matches
```

## Adding a new item

The **Skill** item contract (discovery rules a contributor must follow):

1. Create a directory under `skills/<name>/` using lowercase with hyphens (e.g., `skills/my-skill/`).
2. Add a `SKILL.md` with YAML frontmatter carrying the `name`, `description`, and `version`:

   ```yaml
   ---
   name: my-skill
   description: What this skill does and when to use it.
   version: 1.0.0
   ---
   ```

   **Vendored skills** additionally carry the provenance block — normative for every vendored skill, absent for originals (absence unambiguously means "we wrote this"; see [ADR-0008](adr/0008-vendor-upstream-skills-in-repo.md)):

   ```yaml
   license: LICENSE
   metadata:
     upstream: mattpocock/skills
     upstream-sha: <40-char commit SHA>
     vendored: unedited | amended
   ```

   `version:` on a vendored skill is a local monotonic semver (starting `1.0.0`, bumped on every re-import or amendment); the upstream commit SHA is provenance in the `metadata:` block, not a version. See [Importing a vendored skill](#importing-a-vendored-skill) for the full procedure.

3. Optionally add subdirectories:
   - `references/` — supplementary documentation (keep under 200 lines each)
   - `scripts/` — executable helper code
   - `templates/` — file templates with `{Placeholder}` markers
   - `assets/` — static files (config, data, images)

**Discovery rules.** The manager discovers skills by listing directories under the **Source** `skills/` directory that contain a `SKILL.md`, reads the `version:` field for the **Version**, and deploys the whole directory to the **Target** `~/.agents/skills/`. Keep `SKILL.md` under 500 lines; move detailed content to `references/`.

This repository follows the [Skills Directory file structure spec](https://www.skillsdirectory.com/docs/skill-file-structure).

## Importing a vendored skill

The workflow's upstream skills come from [`mattpocock/skills`](https://github.com/mattpocock/skills) and are vendored in-repo under the Skill Manager — `npx skills` is retired for this source ([ADR-0008](adr/0008-vendor-upstream-skills-in-repo.md)). This is the mechanical procedure for a first import and for every re-import, so importing an eighteenth skill is the same steps as the first:

1. **Copy from a specific upstream commit.** Fetch the skill's directory from `mattpocock/skills` at a specific commit and record that commit's 40-char SHA (e.g. `git rev-parse <ref>` in a clone of the upstream repo).
2. **Assign the local version.** First import: `version: 1.0.0`. Every re-import or amendment bumps the local monotonic semver — it answers "which copy of this skill is deployed", the manager's only question.
3. **Add the provenance frontmatter.** In the skill's `SKILL.md`, alongside `name`/`description`/`version`:

   ```yaml
   license: LICENSE
   metadata:
     upstream: mattpocock/skills
     upstream-sha: <40-char commit SHA>
     vendored: unedited | amended
   ```

   SHA semantics: for **unedited** skills `upstream-sha` is the exact imported commit and moves with the version on re-import; for **amended** skills it is the fork point and stays put while the version moves.
4. **Bundle the license.** Place the verbatim upstream MIT `LICENSE` — including the copyright notice — in the skill's own directory, referenced by `license:`. Per-skill (not shared), so attribution survives any copy-out of an individual skill.
5. **Choose the tier.** **Unedited**: byte-identical to the recorded commit apart from the added frontmatter lines. **Amended**: imported with deliberate local amendments — record the fork point in `upstream-sha` and keep the amendments as deliberate, visible commits.

Original (repo-authored) skills carry no provenance block.

### Standing rinse

The forklift — the bulk refresh that copies the whole upstream skills directory and the agents into this repo — can overwrite this repo's own choices. After every forklift run, re-verify and re-apply:

- the unedited `code-review` content — byte-identical to its recorded upstream commit apart from the frontmatter lines — with `vendored: unedited` and its local version intact;
- the `reviewer` agent's parallel wording — it delegates the skill's two axes in parallel to `axis-reviewer` children.

## Invariants & caveats

- **Local-only deployment.** Items are developed in-repo and deployed locally. No registry, no publishing, no remote sync.
- **Backup is a safety net — no rollback.** Upgrades create a timestamped **Backup** as a **sibling** of the Target, `<target-name>.backups/` (see [ADR-0003](adr/0003-backups-are-siblings-of-the-target.md)), before replacing the installation. The Backup exists only to recover from a bad upgrade; there is no rollback command.
- **Upgrade All never installs.** `upgrade-all` only upgrades items present in both **Source** and **Target** where the **Source** version is newer. Items not installed are skipped; items whose Source version is older are skipped with a warning instead of failing.
- **Version-gated idempotency.** On `install`, a matching version without `--reinstall` is a skipped no-op, and a Source version older than the installed one fails unless `--reinstall` is passed.
- **Edit in Source, not Target.** Develop in the **Source** `skills/` directory; the **Target** `~/.agents/skills/` is a deploy artifact, never the place to edit.

---

_Tracks `scripts/skill-manager.sh` and `CONTEXT.md`. Run `bash scripts/skill-manager.sh --help` for the current command reference._
