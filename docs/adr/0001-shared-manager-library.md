# ADR-0001: Shared Manager Library

**Date**: 2026-08-13
**Status**: Accepted

## Context

Both `skill-manager.sh` and `mcp-manager.sh` implement the same core lifecycle: discover items, extract versions, compare semver, and install/upgrade/uninstall with backups. The logic overlaps ~80%. Building them separately would duplicate CLI parsing, versioning, discovery, and backup code.

## Decision

Extract shared logic into `scripts/agent-manager-lib.sh`. Both managers are thin wrappers that source the library and add type-specific behavior.

**Shared library provides:**

- CLI argument parsing (`--reinstall`, `--dry-run`, `--source`, `--help`)
- Version extraction (YAML frontmatter and Python header comment formats)
- Semver comparison (`semver_gt`)
- Item discovery (`list_items_in_dir`)
- Install, upgrade, and backup operations (`do_install`, `do_upgrade`)
- Color helpers and idempotency guard

**Managers add:**

- `skill-manager.sh` — target directory, SKILL.md discovery, plain copy
- `mcp-manager.sh` — target directory, venv management, pip install, `mcp-config.json` updates, `.py` entrypoint resolution

## Consequences

- **Positive**: Single source of truth for lifecycle logic. New item types add a thin wrapper, not a full manager.
- **Positive**: Managers remain focused on their type-specific concerns.
- **Negative**: Library grows as both managers' needs converge. Risk of over-generalization if MCP Servers diverge significantly (e.g., registry, health checks, multi-tenancy).
- **Neutral**: Skills and MCP Servers remain peers — the library is infrastructure, not a domain abstraction.
