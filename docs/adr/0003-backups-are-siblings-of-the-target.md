# ADR-0003: Backups Are Siblings of the Target, Not Subfolders

**Date**: 2026-08-27
**Status**: Accepted

## Context

Each manager wrote its Backup *inside* its Target — `<target>/backups/` (e.g. `~/.agents/skills/backups/`). For Skills this meant the manager created timestamped skill copies inside `~/.agents/skills/`, the exact directory pi scans for skills. Because the backups carried the same `name:` frontmatter as the live skills, pi reported them as **name collisions**. There is no pi config to exclude a path, so the only fix was to stop the backups living in the scanned tree.

## Decision

The Backup is always a **sibling** of the Target, named `<target-name>.backups`, never a subfolder of the Target:

- skill-manager → `~/.agents/skills.backups/`
- mcp-manager → `~/.agents/mcp.backups/`
- copilot-agent-manager → `~/.copilot/agents.backups/`

Each manager sets `BACKUP_DIR` explicitly to its sibling; the shared library reads `BACKUP_DIR` unchanged.

## Considered Options

- **Keep `<target>/backups/` (subfolder).** Rejected — this is the source of the collision for Skills and nests the Backup inside the deploy artifact it protects.
- **A single shared backup root (e.g. `~/.agents/skills-backups/`).** Rejected — Copilot Agents live under `~/.copilot/`, so no single parent fits all three managers uniformly.
- **Dotted sibling `<target-name>.backups`.** Chosen — fits all three managers uniformly, stays next to its Target, and (for Skills) is outside the directory pi scans.

## Consequences

- **Positive**: pi no longer discovers Skill backups, so the collision is gone and stays gone across upgrades.
- **Positive**: A Backup never lives inside the thing it backs up — uninstalling/clearing a Target can't destroy its restore history.
- **Negative**: Existing backups must be migrated once from the old `<target>/backups/` paths to the new siblings; the script edits must precede the move so a concurrent upgrade can't recreate the old path.
- **Neutral**: Only the Skill path had the collision in practice — MCP and Copilot targets are not pi-scanned — but all three were unified for one consistent rule.
