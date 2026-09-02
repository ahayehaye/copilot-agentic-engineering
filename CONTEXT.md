# Context

Reusable agent skills and MCP servers for coding assistants, managed locally from source.

## Glossary

| Term | Definition |
|------|------------|
| **Skill** | A reusable agent capability. A directory under `skills/` containing `SKILL.md` with YAML frontmatter (`name`, `description`, `version`). May include `references/`, `scripts/`, `templates/`, and `assets/` subdirectories. Installed to `~/.agents/skills/`. |
| **MCP Server** | A Python-based Model Context Protocol server. A directory under `mcp-servers/` containing at least one `.py` file (with `# version: X.Y.Z` header) and a `requirements.txt`. Installed to `~/.agents/mcp/`, with dependencies in a shared virtualenv. |
| **Copilot Agent** | A custom Copilot CLI agent definition. A directory under `copilot-agents/` containing `*.agent.md` with YAML frontmatter (`name`, `description`, `version`). Installed to `~/.copilot/agents/`. |
| **Copilot Instructions** | The user-global instructions file for the GitHub Copilot CLI — rules injected verbatim into every prompt. **Source**: `copilot-instructions/copilot-instructions.md`, a single Markdown file with no frontmatter and no version marker (an in-file marker would leak into prompts). **Target**: `${COPILOT_HOME:-~/.copilot}/copilot-instructions.md` (honors the Copilot CLI's `COPILOT_HOME` redirect). Because the file carries no version, versioning is by content hash: the SHA-256 of the Source at install time is recorded in a state dotfile (`.copilot-instructions.sha256`) next to the Target. The lifecycle is install-if-missing with a drift warning — a differing Target is never clobbered, and `reinstall` is the only adoption path. See [ADR-0007](docs/adr/0007-copilot-instructions-install-if-missing.md). |
| **pi** | The pi.dev coding harness — the `pi` CLI for agent-assisted software development, distinct from the GitHub Copilot CLI. |
| **Copilot Launcher** | A repo-only script (`scripts/copilot-launch.sh`) that starts a GitHub Copilot session by exec-ing `copilot -i "/agent <name>"` — the agent-selection slash command is the session's FIRST INSTRUCTION, and the selected Copilot Agent's own instructions are what run. Two modes: an agent name as argument (scriptable), or bare invocation showing an interactive picker of the deployed agents plus a plain-session entry (a bare `exec copilot` with no first instruction). It resolves agents from the installed agents directory (the Target) — flat `*.agent.md` files, name = filename minus the suffix, frontmatter not parsed — honoring the `COPILOT_HOME` redirect (`${COPILOT_HOME:-~/.copilot}/agents`); the repo Source (`copilot-agents/`) is never consulted. An empty Target is a non-fatal warning in the picker (degrades to the plain-session entry only); an unknown agent in scriptable mode is a hard error listing the tried location and available names. Not a Manager — no lifecycle, no shared-library sourcing, no state; read-only over the installed agents. The user maintains a personal PATH wrapper pointing at it. |
| **Dangerous-command guard** | The pi bash-tool guard that flags destructive commands before execution and blocks them in any session that lacks a confirmation UI. It matches three trigger categories: `rm` immediately followed by a recursive flag (`rm -r`, `rm -rf`, `rm -r -f`, `rm --recursive`; the flag must follow `rm ` directly, so `rm -fr` does not trip it), any command that contains `sudo`, and `chmod`/`chown` invoked with the `777` mode. In a session without a confirmation UI — a subagent dispatched via the `Agent` tool, or a non-interactive `pi -p` run — it does not prompt; it issues `Dangerous command blocked (no UI for confirmation)`. Interactive pi sessions, where a human can confirm, are not blocked. |
| **Manager** | A CLI wrapper script that sources `agent-manager-lib.sh` and adds type-specific behavior. `skill-manager.sh` manages Skills; `mcp-manager.sh` manages MCP Servers; `copilot-agent-manager.sh` manages Copilot Agents; `copilot-instructions-manager.sh` manages Copilot Instructions. |
| **Agent Manager** | `copilot-agent-manager.sh` — CLI tool for installing, upgrading, and uninstalling Copilot Agents. Discovers agents under `copilot-agents/` and deploys them to `~/.copilot/agents/`. |
| **Instructions Manager** | `copilot-instructions-manager.sh` — a thin wrapper over the Shared Library that manages the Copilot Instructions file. Commands: `install` (install-if-missing; a differing Target prints a drift warning + unified diff and exits 0), `status` (not-installed / up-to-date / source-updated / drifted / user-managed, via three-way hash comparison of Target, Source, and recorded state), and `reinstall` (the only adoption path: timestamped Backup in the sibling `copilot-instructions.backups/`, then replace, then refresh the state file). No automatic upgrade, no uninstall. See [ADR-0007](docs/adr/0007-copilot-instructions-install-if-missing.md). |
| **Shared Library** | `scripts/agent-manager-lib.sh` — common logic (version extraction, semver comparison, discovery, install, upgrade, backup, and the ADR-0007 drift helpers: content hash, three-way drift classification, and drift diff) sourced by the four wrapper managers (skill, mcp, copilot-agent, copilot-instructions). |
| **Source** | The repo directory where items live before installation (`skills/`, `mcp-servers/`, or `copilot-agents/`). |
| **Target** | The user's home directory where items are installed (`~/.agents/skills/`, `~/.agents/mcp/`, or `~/.copilot/agents/`). |
| **Version** | Semantic version string extracted from file headers: YAML frontmatter (`version:`) for Skills and Copilot Agents, Python comment (`# version:`) for MCP Servers. |
| **Backup** | Timestamped copy of a previous installation, created automatically before each upgrade. Stored as a **sibling** of the Target, never inside it — at `<target-name>.backups/` (e.g. `~/.agents/skills.backups/`, `~/.agents/mcp.backups/`, `~/.copilot/agents.backups/`). Safety net only — no rollback command. |
| **Upgrade All** | A manager command that upgrades only items present in both Source and Target where Source is semver-newer; never installs uninstalled items. Counterpart to `install-all` for repos that carry experimental or deprecated items in Source. |
| **Smoke Test** | A validation skill (`mcp-smoke-test`) that installs an MCP server, verifies registration and tool execution, then cleans up. |
| **Plan Proposal** | A docs-first skill (`plan-from-docs`) that studies the project's domain docs and relevant code, then proposes a complete plan in one pass — no interview. The user revises it through a Q&A loop until explicitly accepting. |
| **Line Ending Normalization** | The policy that every text file in the repo is stored and checked out as LF only. Enforced by the catch-all `* text=auto eol=lf` rule in `.gitattributes`, which normalizes CRLF → LF on commit (so the repository never stores a CR byte) and forces LF on checkout (so the working tree stays LF on every machine, overriding `core.autocrlf`). The repo is all-text with zero tracked CR bytes, so the rule is a no-op today. Documented in [ADR-0006](docs/adr/0006-line-ending-normalization.md); a defensive on-disk CR-strip guard in `scripts/agent-manager-lib.sh` is its runtime companion. |
| **Topic Branch** | A git branch for implementing a parent ticket, named with Conventional Commits: `<type>/#<number>-<short-slug>` (e.g. `feat/#100-add-cool-new-thing`); the `#` is intentional. The analyst suggests one at the end of `/to-tickets`; the user creates it. |
| **Vertical Slice** | A single unit of implementation work (a.k.a. tracer bullet) that cuts a narrow but complete path through every layer, sized to fit in one fresh context window. The unit the director dispatches to a worker. |
| **Blocking Edge** | A dependency between two tickets: one ticket blocks another until the blocker is complete. Defined by `/to-tickets`; its portable form is a `Blocked by:` line in the blocked ticket's body, which tracker-native blocking links may mirror. |
| **Logic Error** | A failure class: a bug in the implementation code. Retryable once with the error logs appended to the worker's context. |
| **Context Error** | A failure class: the vertical slice itself is the problem — too large for one context window, or its task context is ambiguous or inconsistent. A retry cannot fix it; it requires re-planning or re-slicing. |

## Item Contracts

Discovery rules a contributor must follow to add a new installable item:

- **Skill**: Create a directory under `skills/<name>/` containing `SKILL.md` with YAML frontmatter (`name`, `description`, `version`). Follow the [Skills Directory file structure spec](https://www.skillsdirectory.com/docs/skill-file-structure).
- **MCP Server**: Create a directory under `mcp-servers/<name>/` containing at least one `.py` file (with `# version: X.Y.Z` header comment) and a `requirements.txt`.
- **Copilot Agent**: Create a directory under `copilot-agents/<name>/` containing `*.agent.md` with YAML frontmatter (`name`, `description`, `version`).

## Lifecycle

Skills, MCP Servers, and Copilot Agents share the same version-gated lifecycle:

```
  ┌──────────┐  install  ┌──────────┐  new version in source  ┌──────────┐
  │  Source  │ ────────► │ Installed│ ──────────────────────► │ Upgraded │
  └──────────┘           └────┬─────┘                         └────┬─────┘
                              │ uninstall                          │ uninstall
                              ▼                                    ▼
                         ┌──────────┐                         ┌──────────┐
                         │ Removed  │                         │ Removed  │
                         └──────────┘                         └──────────┘
```

On `install`, the manager decides:

| Condition | Action |
|-----------|--------|
| Target does not exist | **Install** — fresh copy from source |
| Same version, no force | **Skip** — idempotent no-op |
| Source version newer | **Upgrade** — backup current, then replace |
| Source version older | **Fail** — unless `--reinstall` forces it |

On `upgrade-all`, the install action never occurs: items not installed in Target are **Skip**ped as not-installed, and items whose Source version is older are **Skip**ped with a warning instead of failing.

MCP Servers add post-install hooks: venv creation, `pip install`, and `mcp-config.json` update.

## Invariants

- **Local-only deployment**: Items are developed in-repo and deployed locally. No registry, no publishing, no remote sync.
- **MCP Config consistency**: After any MCP server install, upgrade, or uninstall, `~/.copilot/mcp-config.json` (under `mcpServers` key) must reflect exactly the set of installed servers. Stale entries cause connection errors; missing entries hide tools.
- **Shared virtualenv**: All MCP servers share a single virtualenv at `~/.agents/mcp/.venv/`. Dependencies are installed into this shared environment, not per-server.

## Notes

- Skills, MCP Servers, and Copilot Agents are peers — none is a subtype of another. The shared library is infrastructure, not a domain abstraction.
- Skills may reference MCP Servers in their procedural instructions, but no formal dependency tracking exists yet. The `requires` frontmatter field (per [Skills Directory spec](https://www.skillsdirectory.com/docs/skill-md-format)) is available but not yet used.
