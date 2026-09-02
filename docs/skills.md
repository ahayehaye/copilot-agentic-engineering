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

3. Optionally add subdirectories:
   - `references/` — supplementary documentation (keep under 200 lines each)
   - `scripts/` — executable helper code
   - `templates/` — file templates with `{Placeholder}` markers
   - `assets/` — static files (config, data, images)

**Discovery rules.** The manager discovers skills by listing directories under the **Source** `skills/` directory that contain a `SKILL.md`, reads the `version:` field for the **Version**, and deploys the whole directory to the **Target** `~/.agents/skills/`. Keep `SKILL.md` under 500 lines; move detailed content to `references/`.

This repository follows the [Skills Directory file structure spec](https://www.skillsdirectory.com/docs/skill-file-structure).

## Invariants & caveats

- **Local-only deployment.** Items are developed in-repo and deployed locally. No registry, no publishing, no remote sync.
- **Backup is a safety net — no rollback.** Upgrades create a timestamped **Backup** as a **sibling** of the Target, `<target-name>.backups/` (see [ADR-0003](adr/0003-backups-are-siblings-of-the-target.md)), before replacing the installation. The Backup exists only to recover from a bad upgrade; there is no rollback command.
- **Upgrade All never installs.** `upgrade-all` only upgrades items present in both **Source** and **Target** where the **Source** version is newer. Items not installed are skipped; items whose Source version is older are skipped with a warning instead of failing.
- **Version-gated idempotency.** On `install`, a matching version without `--reinstall` is a skipped no-op, and a Source version older than the installed one fails unless `--reinstall` is passed.
- **Edit in Source, not Target.** Develop in the **Source** `skills/` directory; the **Target** `~/.agents/skills/` is a deploy artifact, never the place to edit.

---

_Tracks `scripts/skill-manager.sh` and `CONTEXT.md`. Run `bash scripts/skill-manager.sh --help` for the current command reference._
