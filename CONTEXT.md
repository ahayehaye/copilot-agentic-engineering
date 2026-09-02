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
| **pi Package** | An npm package installed via `pi install` (e.g., `pi-mcp-adapter`). Declared in the Manifest's `packages` list. |
| **pi Extension** | A directory under `pi/extensions/` containing `index.ts` with a `// version:` header comment. Deployed to pi's extensions directory. |
| **Agent Profile** | A directory under `pi/agents/` containing a Markdown file with YAML frontmatter (`name`, `description`, `tools`, `model`, `version`). Deployed to pi's agents directory. |
| **Pi Role Profile** | An Agent Profile named for the workflow role it hosts: `analyst`, `director`, `worker`, `reviewer` — mirroring the Copilot role names — plus `scout`, a utility explorer. The generic `planner` profile is retired in favor of `director`. Role profiles carry no `model:` pin — every role inherits pi's default provider, the `llama-swap` provider id exposed by the `pi-llama-swap` extension (the underlying inference server is the local llama.cpp server); model selection lives in the extension and pi settings, never in the profile. |
| **Pi Keybindings** | The user-global pi keybindings file — a JSON object mapping pi's namespaced action ids (e.g., `tui.input.newLine`) to a key string or an array of key strings. **Source**: `pi/keybindings.json`, a single JSON file with no version marker (a `version` key would be an unknown action id to pi). **Target**: `~/.pi/agent/keybindings.json`. Because the file carries no version, versioning is by content hash: the SHA-256 of the Source at install time is recorded in a state dotfile (`.keybindings.sha256`) next to the Target. The lifecycle is install-if-missing with a drift warning — a differing Target is never clobbered (the warning classifies it as source-updated / drifted / user-managed and prints a unified diff), and `install keybindings/keybindings --reinstall` is the only adoption path (timestamped Backup in the sibling `keybindings.backups/`, per [ADR-0003](docs/adr/0003-backups-are-siblings-of-the-target.md)). No automatic upgrade, no uninstall; keybinding changes apply via `/reload` or the next pi session. See [ADR-0008](docs/adr/0008-pi-keybindings-install-if-missing.md). Terminal input quirks (e.g., Shift+Enter on legacy terminals) are troubleshooting territory, not a manager concern — see [docs/pi-keybindings.md](docs/pi-keybindings.md). |
| **Provider ID** | The id pi registers a model source under via `pi.registerProvider`, e.g. `llama-swap` — the id the `pi-llama-swap` extension exposes. It is distinct from the inference server name (`llama.cpp`, the local server that actually runs the model) and from `defaultProvider` (the user's default provider in pi `settings.json`, which must equal a registered provider id). If `defaultProvider` in `~/.pi/agent/settings.json` does not equal a registered provider id, pi's resolved default falls back to the built-in OpenAI provider, which has no valid key, so a bare non-interactive `pi -p` run 401s. The correct value here is `"defaultProvider": "llama-swap"` (additive — preserve existing keys in `~/.pi/agent/settings.json`); this is a user-local change the repo documents and hands to the user, it does not edit the file.
| **Pi Launcher** | A repo-only script (`scripts/pi-launch.sh`) that starts a pi role session by exec-ing `pi --append-system-prompt <role-file>`, appending the project `.pi/APPEND_SYSTEM.md` and the global `APPEND_SYSTEM.md` as further values when present (order: role, project, global). Two modes: a role name as argument (scriptable), or bare invocation showing an interactive list of the deployed role profiles. It resolves the role file and passes it through — no provider, model, or flag logic of its own. Not managed by the pi Manager; the user maintains a personal PATH wrapper pointing at it. |
| **Copilot Launcher** | A repo-only script (`scripts/copilot-launch.sh`) that starts a GitHub Copilot session by exec-ing `copilot -i "/agent <name>"` — the agent-selection slash command is the session's FIRST INSTRUCTION, and the selected Copilot Agent's own instructions are what run. Two modes: an agent name as argument (scriptable), or bare invocation showing an interactive picker of the deployed agents plus a plain-session entry (a bare `exec copilot` with no first instruction). It resolves agents from the installed agents directory (the Target) — flat `*.agent.md` files, name = filename minus the suffix, frontmatter not parsed — honoring the `COPILOT_HOME` redirect (`${COPILOT_HOME:-~/.copilot}/agents`); the repo Source (`copilot-agents/`) is never consulted. An empty Target is a non-fatal warning in the picker (degrades to the plain-session entry only); an unknown agent in scriptable mode is a hard error listing the tried location and available names. Not a Manager — no lifecycle, no shared-library sourcing, no state; read-only over the installed agents. The user maintains a personal PATH wrapper pointing at it. |
| **Subagents Package** | The pi package that provides child-agent dispatch: `@tintinweb/pi-subagents` (Claude Code-style `Agent` tool, `SubagentWorkflow`, agent mentions). Chosen over the same-named `pi-subagents` by nicobailon, whose council/budget machinery is overkill for this workflow. Its global agent directory is `~/.pi/agent/agents/` — the same directory the pi Manager deploys profiles to. Verified facts (agent dir, frontmatter fields) live in [docs/pi-subagents.md](docs/pi-subagents.md); the choice is recorded in [ADR-0005](docs/adr/0005-subagents-package-tintinweb.md). |
| **Dangerous-command guard** | The pi bash-tool guard that flags destructive commands before execution and blocks them in any session that lacks a confirmation UI. It matches three trigger categories: `rm` immediately followed by a recursive flag (`rm -r`, `rm -rf`, `rm -r -f`, `rm --recursive`; the flag must follow `rm ` directly, so `rm -fr` does not trip it), any command that contains `sudo`, and `chmod`/`chown` invoked with the `777` mode. In a session without a confirmation UI — a subagent dispatched via the `Agent` tool, or a non-interactive `pi -p` run — it does not prompt; it issues `Dangerous command blocked (no UI for confirmation)`. Interactive pi sessions, where a human can confirm, are not blocked. |
| **Cross-Harness Parity** | The design principle that the agentic software engineering workflow (analyst → director → worker) behaves the same in the GitHub Copilot CLI and in pi. Copilot is used for day-job work, pi for personal projects; skills are shared via `~/.agents/skills/`, and role profiles are faithful ports of the Copilot agent definitions. |
| **Skill Command** | pi's invocation form for a Skill: `/skill:<name>`, enabled by `enableSkillCommands: true` in pi settings. The pi analogue of a Copilot CLI slash command; arguments are appended to the skill content. |
| **Prompt Template** | A Markdown file under `pi/prompts/` with `version:` YAML frontmatter. Deployed to pi's prompts directory. |
| **pi Skill** | A directory under `pi/skills/` following the SKILL.md contract (`SKILL.md` with YAML frontmatter: `name`, `description`, `version`). Deployed to pi's skills directory. |
| **Manager** | A CLI wrapper script that sources `agent-manager-lib.sh` and adds type-specific behavior. `skill-manager.sh` manages Skills; `mcp-manager.sh` manages MCP Servers; `copilot-agent-manager.sh` manages Copilot Agents; `copilot-instructions-manager.sh` manages Copilot Instructions. |
| **pi Manager** | `pi-manager.sh` — the script that converges pi's desired state: installs missing packages, upgrades outdated extensions, agent profiles, prompt templates, and skills, installs the Pi Keybindings file install-if-missing (drift warning, never a clobber; `--reinstall` is the only adoption path), and converges the APPEND_SYSTEM.md file. |
| **Manifest** | `pi/manifest.json` — declares the pi CLI npm package (`cli.npm_package`), the list of pi Packages to install (`packages`), and the APPEND_SYSTEM.md version (`append_system.version`). |
| **Agent Manager** | `copilot-agent-manager.sh` — CLI tool for installing, upgrading, and uninstalling Copilot Agents. Discovers agents under `copilot-agents/` and deploys them to `~/.copilot/agents/`. |
| **Instructions Manager** | `copilot-instructions-manager.sh` — a thin wrapper over the Shared Library that manages the Copilot Instructions file. Commands: `install` (install-if-missing; a differing Target prints a drift warning + unified diff and exits 0), `status` (not-installed / up-to-date / source-updated / drifted / user-managed, via three-way hash comparison of Target, Source, and recorded state), and `reinstall` (the only adoption path: timestamped Backup in the sibling `copilot-instructions.backups/`, then replace, then refresh the state file). No automatic upgrade, no uninstall. See [ADR-0007](docs/adr/0007-copilot-instructions-install-if-missing.md). |
| **Shared Library** | `scripts/agent-manager-lib.sh` — common logic (version extraction, semver comparison, discovery, install, upgrade, backup, and the ADR-0007 drift helpers: content hash, three-way drift classification, and drift diff) sourced by the four wrapper managers (skill, mcp, copilot-agent, copilot-instructions); the pi Manager is separate. |
| **Source** | The repo directory where items live before installation (`skills/`, `mcp-servers/`, or `copilot-agents/`). |
| **Target** | The user's home directory where items are installed (`~/.agents/skills/`, `~/.agents/mcp/`, or `~/.copilot/agents/`). |
| **Version** | Semantic version string extracted from file headers: YAML frontmatter (`version:`) for Skills and Copilot Agents, Python comment (`# version:`) for MCP Servers. |
| **Backup** | Timestamped copy of a previous installation, created automatically before each upgrade. Stored as a **sibling** of the Target, never inside it — at `<target-name>.backups/` (e.g. `~/.agents/skills.backups/`, `~/.agents/mcp.backups/`, `~/.copilot/agents.backups/`). Safety net only — no rollback command. |
| **Upgrade All** | A manager command that upgrades only items present in both Source and Target where Source is semver-newer; never installs uninstalled items. Counterpart to `install-all` for repos that carry experimental or deprecated items in Source. **Scoped note:** file-copy managers (Skill, MCP, Copilot Agent) never install uninstalled items; the pi Manager converges — it installs missing packages and upgrades outdated items. |
| **Smoke Test** | A validation skill (`mcp-smoke-test`) that installs an MCP server, verifies registration and tool execution, then cleans up. |
| **Plan Proposal** | A docs-first skill (`plan-from-docs`) that studies the project's domain docs and relevant code, then proposes a complete plan in one pass — no interview. The user revises it through a Q&A loop until explicitly accepting. |
| **Line Ending Normalization** | The policy that every text file in the repo is stored and checked out as LF only. Enforced by the catch-all `* text=auto eol=lf` rule in `.gitattributes`, which normalizes CRLF → LF on commit (so the repository never stores a CR byte) and forces LF on checkout (so the working tree stays LF on every machine, overriding `core.autocrlf`). The repo is all-text with zero tracked CR bytes, so the rule is a no-op today. Documented in [ADR-0006](docs/adr/0006-line-ending-normalization.md); a defensive on-disk CR-strip guard in `scripts/agent-manager-lib.sh` is its runtime companion. |
| **Topic Branch** | A git branch for implementing a parent ticket, named with Conventional Commits: `<type>/#<number>-<short-slug>` (e.g. `feat/#100-add-cool-new-thing`); the `#` is intentional. The analyst suggests one at the end of `/to-tickets`; the user creates it. |
| **Vertical Slice** | A single unit of implementation work (a.k.a. tracer bullet) that cuts a narrow but complete path through every layer, sized to fit in one fresh context window. The unit the director dispatches to a worker. |
| **Blocking Edge** | A dependency between two tickets: one ticket blocks another until the blocker is complete. Defined by `/to-tickets`; its portable form is a `Blocked by:` line in the blocked ticket's body, which tracker-native blocking links may mirror. |
| **Logic Error** | A failure class: a bug in the implementation code. Retryable once with the error logs appended to the worker's context. |
| **Context Error** | A failure class: the vertical slice itself is the problem — too large for one context window, or its task context is ambiguous or inconsistent. A retry cannot fix it; it requires re-planning or re-slicing. |
| **Forklift** | The scripted, copy-only transfer of whitelisted Copilot files from this repo into the public checkout. See [docs/public-forklift.md](docs/public-forklift.md). |
| **Rinse pass** | The LLM-assisted review of the public checkout that removes private-repo references before the first push. |
| **Public repo** | The rinsed, public subset of this repo. |

## Item Contracts

Discovery rules a contributor must follow to add a new installable item:

- **Skill**: Create a directory under `skills/<name>/` containing `SKILL.md` with YAML frontmatter (`name`, `description`, `version`). Follow the [Skills Directory file structure spec](https://www.skillsdirectory.com/docs/skill-file-structure).
- **MCP Server**: Create a directory under `mcp-servers/<name>/` containing at least one `.py` file (with `# version: X.Y.Z` header comment) and a `requirements.txt`.
- **Copilot Agent**: Create a directory under `copilot-agents/<name>/` containing `*.agent.md` with YAML frontmatter (`name`, `description`, `version`).
- **pi Extension**: Create a directory under `pi/extensions/<name>/` containing `index.ts` with a `// version: X.Y.Z` header comment.
- **Agent Profile**: Create a directory under `pi/agents/<name>/` containing a Markdown file with YAML frontmatter (`name`, `description`, `tools`, `model`, `version`).
- **Prompt Template**: Create a Markdown file under `pi/prompts/<name>.md` with `version:` YAML frontmatter.
- **pi Skill**: Create a directory under `pi/skills/<name>/` containing `SKILL.md` with YAML frontmatter (`name`, `description`, `version`).
- **Manifest**: Maintain `pi/manifest.json` with `cli.npm_package` (the pi CLI npm package), `packages` (list of pi Packages to install), and `append_system.version` (the APPEND_SYSTEM.md version).

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
