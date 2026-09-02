# Copilot Agents

## What it is

`copilot-agent-manager.sh` is the **Agent Manager** for **Copilot Agents** — it installs, upgrades, and uninstalls them, moving items from the **Source** `copilot-agents/` directory to the **Target** `~/.copilot/agents/` using the shared version-gated lifecycle. It is a thin wrapper that sources the [Shared Library](adr/0001-shared-manager-library.md); see the [glossary](../CONTEXT.md#glossary) for the full vocabulary (Copilot Agent, Agent Manager, Manager, Source, Target, Version, Backup, Upgrade All).

> [!NOTE]
> **Scope and the word "agent".** This page documents the **Copilot Agent** *item type* — the installable `*.agent.md` files managed by the Agent Manager. It does **not** describe the pipeline *roles* (analyst, director, worker) that run the workflow skills. Keep the two senses of "agent" separate:
>
> - **Agent (item type):** an installable `*.agent.md` under `copilot-agents/`, deployed to `~/.copilot/agents/`. This page is about these.
> - **Agent (pipeline role):** the participant role — analyst, director, or worker — that plays out in the workflow. These roles are covered in [workflows/flow-notes.md](workflows/flow-notes.md) and [workflows/three-sizes.md](workflows/three-sizes.md); this page does not describe what they do.

## Install / upgrade / uninstall

Commands come from `bash scripts/copilot-agent-manager.sh --help`:

```
Usage: copilot-agent-manager.sh <command> [options] [args]

Commands:
  install <agent-name>          Install or upgrade a single agent
  install-all                   Install all agents from source
  upgrade <agent-name>          Alias for install <agent-name>
  upgrade-all                   Upgrade installed agents with newer source versions
  uninstall <agent-name>        Remove an installed agent
  list                          Show installed agents with versions
  list-available                Show agents available in source
  status                        Compare installed vs available (outdated/new)

Options:
  --reinstall, -f               Force reinstall even if version matches
  --dry-run, -n                 Preview changes without making them
  --source <path>               Override auto-detected copilot-agents/ directory
  --help, -h                    Show usage
```

Common flows:

```bash
bash scripts/copilot-agent-manager.sh install my-agent      # install, or upgrade if newer
bash scripts/copilot-agent-manager.sh install-all           # install every agent in source
bash scripts/copilot-agent-manager.sh upgrade my-agent      # alias for install my-agent
bash scripts/copilot-agent-manager.sh upgrade-all           # newer source versions only
bash scripts/copilot-agent-manager.sh uninstall my-agent    # remove an installed agent
bash scripts/copilot-agent-manager.sh list                  # installed agents + versions
bash scripts/copilot-agent-manager.sh list-available        # agents available in source
bash scripts/copilot-agent-manager.sh status                # installed vs available
```

Options:

```bash
bash scripts/copilot-agent-manager.sh install my-agent --dry-run    # preview, change nothing
bash scripts/copilot-agent-manager.sh install my-agent --reinstall  # force even if version matches
bash scripts/copilot-agent-manager.sh install my-agent --source ./copilot-agents   # override auto-detected source
```

## Adding a new item

The **Copilot Agent** item contract (discovery rules a contributor must follow):

1. Create a directory under `copilot-agents/<name>/` using lowercase with hyphens (e.g., `copilot-agents/my-agent/`).
2. Add a `*.agent.md` file with YAML frontmatter carrying the `name`, `description`, and `version`:

   ```yaml
   ---
   name: my-agent
   description: What this agent does and when to use it.
   version: 1.0.0
   ---
   ```

**Discovery rules.** The Agent Manager discovers agents by listing directories under the **Source** `copilot-agents/` directory that contain a `*.agent.md` file, reads the `version:` field for the **Version**, and deploys that `*.agent.md` file to the **Target** `~/.copilot/agents/<name>.agent.md`.

## Invariants & caveats

- **Local-only deployment.** Items are developed in-repo and deployed locally. No registry, no publishing, no remote sync.
- **Backup is a safety net — no rollback.** Upgrades create a timestamped **Backup** as a **sibling** of the Target, `<target-name>.backups/` (see [ADR-0003](adr/0003-backups-are-siblings-of-the-target.md)), before replacing the installation. The Backup exists only to recover from a bad upgrade; there is no rollback command.
- **Version-gated idempotency.** On `install`, a matching version without `--reinstall` is a skipped no-op, and a Source version older than the installed one fails unless `--reinstall` is passed. `upgrade-all` skips not-installed and older items instead of failing.
- **Edit in Source, not Target.** Develop in the **Source** `copilot-agents/` directory; the **Target** `~/.copilot/agents/` is a deploy artifact, never the place to edit.

---

_Tracks `scripts/copilot-agent-manager.sh` and `CONTEXT.md`. Run `bash scripts/copilot-agent-manager.sh --help` for the current command reference._
