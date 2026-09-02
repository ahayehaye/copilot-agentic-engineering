# Manager Library

## What it is

`scripts/agent-manager-lib.sh` is the **Shared Library** for the three version-gated item managers. It holds the version-gated lifecycle logic — version extraction, semver comparison, item discovery, install, upgrade, and backup — that **Skills**, **MCP Servers**, and **Copilot Agents** all share, so the three managers behave identically. The library is sourced (not executed) by thin wrapper scripts; the wrappers (`skill-manager.sh`, `mcp-manager.sh`, `copilot-agent-manager.sh`) add only their type-specific behavior. A fourth wrapper, `copilot-instructions-manager.sh`, sources the same library but deliberately deviates from the version-gated lifecycle — see the [Copilot Instructions Manager](#copilot-instructions-manager-deliberate-deviation) section and [ADR-0007](adr/0007-copilot-instructions-install-if-missing.md).

The rationale for this shape — why all three managers share one library and behave identically — lives in the [Shared Library ADR](adr/0001-shared-manager-library.md); this page documents the resulting command surface, wrapper variables, and invariants rather than restating that decision. Related vocabulary (Shared Library, Manager, Source, Target, Version, Backup, Upgrade All) is in the [glossary](../CONTEXT.md#glossary).

## Shared commands and flags

All three managers expose the same command surface; they differ only in the item noun (skill / MCP server / agent) and the auto-detected **Source** directory (`skills/`, `mcp-servers/`, `copilot-agents/`). Capture it from any manager's `--help`:

```
Usage: <manager>.sh <command> [options] [args]

Commands:
  install <item>            Install or upgrade a single item
  install-all               Install all items from source
  upgrade <item>            Alias for install <item>
  upgrade-all               Upgrade installed items with newer source versions
  uninstall <item>          Remove an installed item
  list                      Show installed items with versions
  list-available            Show items available in source
  status                    Compare installed vs available (outdated/new)

Options:
  --reinstall, -f           Force reinstall even if version matches
  --dry-run, -n             Preview changes without making them
  --source <path>           Override auto-detected source directory
  --help, -h                Show usage
```

Commands:

- `install <item>` — install a fresh item, or upgrade it when the **Source** version is newer.
- `install-all` — install every item in the **Source**; also upgrades already-installed items with a newer **Source** version.
- `upgrade <item>` — alias for `install <item>`.
- `upgrade-all` — upgrade only items present in both **Source** and **Target** where **Source** is semver-newer; never installs uninstalled items.
- `uninstall <item>` — remove an installed item.
- `list` — installed items with versions.
- `list-available` — items available in **Source**.
- `status` — installed vs available, marking items outdated or new.

Options:

- `--reinstall, -f` — force even when the version matches.
- `--dry-run, -n` — preview changes without making them.
- `--source <path>` — override the auto-detected **Source** directory.
- `--help, -h` — show usage.

## Copilot Instructions Manager (deliberate deviation)

`copilot-instructions-manager.sh` manages a single file — the **Copilot Instructions** (`copilot-instructions/copilot-instructions.md` → `${COPILOT_HOME:-~/.copilot}/copilot-instructions.md`) — and deliberately deviates from the version-gated lifecycle above. The file is injected verbatim into every Copilot prompt, so it carries no version marker; and the Target may be user-authored, so it is never clobbered. The decision and rationale live in [ADR-0007](adr/0007-copilot-instructions-install-if-missing.md); this section documents the resulting command surface.

Commands:

```
Usage: copilot-instructions-manager.sh <command> [options]

Commands:
  install         Install the instructions file if missing (never clobbers;
                  on a differing target, prints a drift warning + diff)
  status          Show installed state at a glance (up-to-date / source-updated
                  / drifted / user-managed)
  reinstall       Adopt the Source: timestamped backup of the current file,
                  replace target, refresh the state file

Options:
  --reinstall, -f               With install: alias for the reinstall command
  --dry-run, -n                 Preview changes without making them
  --source <path>               Override auto-detected copilot-instructions/ directory
  --help, -h                    Show usage

Target: ${COPILOT_HOME:-~/.copilot}/copilot-instructions.md (COPILOT_HOME defaults to ~/.copilot)
State:  ${COPILOT_HOME:-~/.copilot}/.copilot-instructions.sha256 (SHA-256 of Source at install time)
Backups: ${COPILOT_HOME:-~/.copilot}/copilot-instructions.backups/ (timestamped, sibling of target)
```

- `install` — copies Source → Target only when the Target is missing. A differing Target is never clobbered: a drift warning plus a unified diff is printed, and the command exits 0 (advisory — safe to chain into converge flows). With `install`, `--reinstall`/`-f` is an alias for `reinstall`.
- `status` — reports `not-installed`, `up-to-date`, `source-updated`, `drifted`, or `user-managed`.
- `reinstall` — the only adoption path: timestamped Backup, replace Target, refresh the state file.

Lifecycle matrix (on `install`):

| Condition | Action |
|-----------|--------|
| Target does not exist | **Install** — copy from Source, record SHA-256 in the state file |
| Target hash == Source hash | **Skip** — idempotent no-op |
| Target differs, no state file (user-managed) | **Drift warning** + unified diff, exit 0 — never clobber |
| Target differs, Target == recorded hash (source-updated) | **Drift warning** + unified diff, exit 0 — never clobber |
| Target differs, Target != recorded hash (drifted) | **Drift warning** + unified diff, exit 0 — never clobber |

`reinstall` is the only path that touches an existing Target: timestamped Backup, replace, refresh state. There is no `upgrade`, no `uninstall`, and no automatic adoption.

State and paths:

- **State file**: `.copilot-instructions.sha256` next to the Target — the SHA-256 of the Source at install time (content-hash versioning; the file itself carries no version marker). `status` classifies the Target by three-way hash comparison of Target, Source, and recorded state.
- **Backup location**: `copilot-instructions.backups/` — a **sibling** of the Target, per [ADR-0003](adr/0003-backups-are-siblings-of-the-target.md); the timestamped copy is made before each `reinstall`. Safety net only — no rollback command.
- **COPILOT_HOME**: the Target is `${COPILOT_HOME:-~/.copilot}/copilot-instructions.md`; the state file and backup directory live in the same directory, so `COPILOT_HOME` redirects all three.
- **Exit semantics**: drift warnings exit 0; missing Source, unreadable Target, or failed copy/backup exit non-zero.

## Adding a new manager

A new manager is a thin wrapper that sources the **Shared Library** and sets three directory variables plus its type-specific behavior:

```bash
source "${SCRIPT_DIR}/agent-manager-lib.sh"

SOURCE_DIR="${SCRIPT_DIR}/../skills"      # Source: where items live in-repo
TARGET_DIR="$HOME/.agents/skills"         # Target: where items are installed
BACKUP_DIR="$HOME/.agents/skills.backups"   # Backup: sibling of Target (see ADR-0003)
```

- `SOURCE_DIR` — the **Source** directory for this item type (`skills/`, `mcp-servers/`, or `copilot-agents/`).
- `TARGET_DIR` — the **Target** directory for this item type (`~/.agents/skills/`, `~/.agents/mcp/`, or `~/.copilot/agents/`).
- `BACKUP_DIR` — the **Backup** directory; set to a **sibling** of the Target at `<target-name>.backups/` (e.g. `~/.agents/skills.backups/`) and holds the timestamped copy made before each upgrade.

The wrapper supplies discovery rules (which files mark an item as installable), the **Version** header format it reads, and any post-install hooks (for example, the MCP Server wrapper creates the shared virtualenv and updates `mcp-config.json`). The shared library provides everything else — argument parsing, version extraction, semver comparison, install, upgrade, and backup.

## Invariants & caveats

- **Local-only deployment.** Items are developed in-repo and deployed locally. No registry, no publishing, no remote sync.
- **Backup is a safety net — no rollback.** Upgrades create a timestamped **Backup** as a **sibling** of the Target, `<target-name>.backups/` (see [ADR-0003](adr/0003-backups-are-siblings-of-the-target.md)), before replacing an installation. The Backup exists only to recover from a bad upgrade; there is no rollback command.
- **Upgrade All never installs.** `upgrade-all` only upgrades items present in both **Source** and **Target** where the **Source** version is newer. Items not installed are skipped as not-installed; items whose **Source** version is older are skipped with a warning instead of failing.
- **Version-gated idempotency.** On `install`, a matching version without `--reinstall` is a skipped no-op, and a **Source** version older than the installed one fails unless `--reinstall` is passed.
- **Edit in Source, not Target.** Develop in the **Source** directory; the **Target** is a deploy artifact, never the place to edit.
- **Infrastructure, not a domain abstraction.** Skills, MCP Servers, and Copilot Agents are peers — the library is shared plumbing, and no item type is a subtype of another.

---

_Tracks `scripts/agent-manager-lib.sh` and `CONTEXT.md`. Run `bash scripts/<manager>.sh --help` for the current command reference._
