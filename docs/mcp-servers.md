# MCP Servers

## What it is

`mcp-manager.sh` is the **Manager** for **MCP Servers** — it installs, upgrades, and uninstalls them, moving items from the **Source** `mcp-servers/` directory to the **Target** `~/.agents/mcp/` using the shared version-gated lifecycle. Unlike the plain-copy managers, each install also creates the shared virtualenv at `~/.agents/mcp/.venv/` and updates `~/.copilot/mcp-config.json` so registration tracks the installed set. It is a thin wrapper that sources the [Shared Library](adr/0001-shared-manager-library.md); see the [glossary](../CONTEXT.md#glossary) for the full vocabulary (MCP Server, Source, Target, Version, Backup, Upgrade All).

## Install / upgrade / uninstall

Commands come from `bash scripts/mcp-manager.sh --help`:

```
Usage: mcp-manager.sh <command> [options] [args]

Commands:
  install <server-name>         Install or upgrade an MCP server
  install-all                   Install all MCP servers from source
  upgrade <server-name>         Alias for install <server-name>
  upgrade-all                   Upgrade installed MCP servers with newer source versions
  uninstall <server-name>       Remove an installed MCP server
  list                          Show installed MCP servers with versions
  list-available                Show MCP servers available in source
  status                        Compare installed vs available (outdated/new)

Options:
  --reinstall, -f               Force reinstall even if version matches
  --dry-run, -n                 Preview changes without making them
  --source <path>               Override auto-detected mcp-servers/ directory
  --help, -h                    Show usage
```

Common flows:

```bash
bash scripts/mcp-manager.sh install sample-server      # install, or upgrade if newer
bash scripts/mcp-manager.sh install-all                # install every MCP server in source
bash scripts/mcp-manager.sh upgrade sample-server      # alias for install sample-server
bash scripts/mcp-manager.sh upgrade-all                # newer source versions only
bash scripts/mcp-manager.sh uninstall sample-server    # remove an installed MCP server
bash scripts/mcp-manager.sh list                       # installed MCP servers + versions
bash scripts/mcp-manager.sh list-available             # MCP servers available in source
bash scripts/mcp-manager.sh status                     # installed vs available
```

Options:

```bash
bash scripts/mcp-manager.sh install sample-server --dry-run    # preview, change nothing
bash scripts/mcp-manager.sh install sample-server --reinstall  # force even if version matches
bash scripts/mcp-manager.sh install sample-server --source ./mcp-servers   # override auto-detected source
```

## Adding a new item

The **MCP Server** item contract (discovery rules a contributor must follow):

1. Create a directory under `mcp-servers/<name>/` using lowercase with hyphens (e.g., `mcp-servers/my-server/`).
2. Add at least one `.py` file as the entrypoint (the manager uses the first `.py` alphabetically) carrying a `# version: X.Y.Z` header comment — this comment is the **Version**.
3. Add a `requirements.txt` listing the server's dependencies.

```python
# version: 0.1.0
# Sample MCP server for testing mcp-manager

import anyio
from mcp.server import Server
from mcp.server.stdio import stdio_server
# ... server implementation
```

```
mcp
```

**Discovery rules.** The manager discovers servers by listing directories under the **Source** `mcp-servers/` directory that contain a `.py` file, reads the `# version:` header for the **Version**, and deploys the whole directory to the **Target** `~/.agents/mcp/`. On install, the dependencies are `pip install`ed into the shared virtualenv and the server is registered in `~/.copilot/mcp-config.json`.

To verify a server installs, registers, and responds, run the [MCP Smoke Test](getting-started.md#running-the-smoke-test) — it installs the server, checks registration in `~/.copilot/mcp-config.json`, exercises each tool, then cleans up. See the [`mcp-smoke-test`](../skills/mcp-smoke-test/SKILL.md) skill for the full procedure.

## Invariants & caveats

- **Local-only deployment.** Items are developed in-repo and deployed locally. No registry, no publishing, no remote sync.
- **Shared virtualenv.** All MCP servers share one virtualenv at `~/.agents/mcp/.venv/`; dependencies are `pip install`ed into it, not per-server.
- **MCP Config consistency.** After any install, upgrade, or uninstall, `~/.copilot/mcp-config.json` (under the `mcpServers` key) must reflect exactly the installed set. Stale entries cause connection errors; missing entries hide tools.
- **Backup is a safety net — no rollback.** Upgrades create a timestamped **Backup** as a **sibling** of the Target, `<target-name>.backups/` (see [ADR-0003](adr/0003-backups-are-siblings-of-the-target.md)), before replacing the installation. The Backup exists only to recover from a bad upgrade; there is no rollback command.
- **Version-gated idempotency.** On `install`, a matching version without `--reinstall` is a skipped no-op, and a Source version older than the installed one fails unless `--reinstall` is passed. `upgrade-all` skips not-installed and older items instead of failing.
- **Edit in Source, not Target.** Develop in the **Source** `mcp-servers/` directory; the **Target** `~/.agents/mcp/` is a deploy artifact, never the place to edit.

---

_Tracks `scripts/mcp-manager.sh` and `CONTEXT.md`. Run `bash scripts/mcp-manager.sh --help` for the current command reference._
