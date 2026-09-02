# ADR-0007: Copilot Instructions Are Installed-if-Missing with a Drift Warning

**Date**: 2026-08-31
**Status**: Accepted

## Context

`copilot-instructions-manager.sh` manages the user-global Copilot CLI instructions file: **Source** `copilot-instructions/copilot-instructions.md` → **Target** `${COPILOT_HOME:-~/.copilot}/copilot-instructions.md`. Two properties of this item differ from everything the Shared Library manages today:

- **The Target may be user-authored.** Unlike the pi Manager's global `APPEND_SYSTEM.md` — a file the pi Manager owns and auto-upgrades — `copilot-instructions.md` is a user-global file the user may have written themselves or edited after installation.
- **The file carries no version marker.** It is injected verbatim into every prompt, so frontmatter or a version comment would leak into the prompt. The semver lifecycle (extract → compare → gate) has nothing to extract.

The Shared Library's install/upgrade lifecycle is semver-gated, and the pi Manager's take-ownership model auto-upgrades the file it owns. Neither fits this item.

## Decision

`copilot-instructions-manager.sh` is a separate thin wrapper over the Shared Library with an **install-if-missing** lifecycle and **content-hash versioning**:

- **`install`** copies Source → Target only when the Target does not exist, and records the SHA-256 of the Source in a state dotfile (`.copilot-instructions.sha256`) next to the Target. A differing Target is **never clobbered**: `install` prints a drift warning plus a unified diff and exits 0 (advisory — safe to chain into converge flows).
- **`status`** reports `not-installed`, `up-to-date`, `source-updated`, `drifted`, or `user-managed` via a three-way hash comparison (Target hash, Source hash, recorded state hash). An existing Target with no state file is `user-managed` — no ownership is assumed; content equality alone is not ownership.
- **`reinstall`** is the only adoption path: a timestamped Backup in the sibling `copilot-instructions.backups/` (per [ADR-0003](0003-backups-are-siblings-of-the-target.md)), then replace the Target, then refresh the state file.
- No automatic upgrade, no uninstall.
- Exit semantics: drift warnings exit 0; missing Source, unreadable Target, or failed copy/backup exit non-zero.
- The Target honors the Copilot CLI's `COPILOT_HOME` redirect (`${COPILOT_HOME:-$HOME/.copilot}`); the state file and backup directory live in the same directory, so `COPILOT_HOME` redirects all three.

## Considered Options

- **The Shared Library's semver lifecycle.** Rejected — the file carries no version marker (it is injected verbatim into prompts), so there is no version to extract or compare; content-hash versioning in the state dotfile is the only viable versioning.
- **The pi Manager's take-ownership model (auto-upgrade).** Rejected — the Target may be user-authored, and a wrong clobber of a user-global file is worse than a skipped upgrade. The pi Manager auto-upgrades `APPEND_SYSTEM.md` because it owns that file; it does not own `copilot-instructions.md`.
- **Extending `copilot-agent-manager.sh`.** Rejected — the "warn, never fail" drift posture would corrupt the Agent Manager's install/upgrade counters and `upgrade-all` semantics, which assume a semver-gated lifecycle where a Source older than the Target fails.
- **Install-if-missing + drift warning + explicit `reinstall`.** Chosen — the manager can only ever add a file the user does not have; every change to an existing file is an explicit user decision.

## Consequences

- **Positive**: A wrong clobber of a user-global file is impossible; the worst the manager does to an existing file is print a diff.
- **Positive**: Drift warnings exit 0, so `install` can be chained into converge flows without failing on drift.
- **Positive**: The three-way hash comparison distinguishes "Source moved" (`source-updated`) from "user edited" (`drifted`) from "never ours" (`user-managed`), so the drift warning tells the user which case they are in.
- **Negative**: Upgrades are never automatic — adopting a Source change requires an explicit `reinstall`; a user who never runs it keeps the old content.
- **Negative**: The state dotfile is required for drift classification; if the user deletes it, the Target reads as `user-managed` and the manager assumes no ownership (the safe direction).
- **Neutral**: Backups follow ADR-0003 (sibling `copilot-instructions.backups/`, safety net only, no rollback command). Verification follows [ADR-0004](0004-no-tests-for-bash-scripts.md) (syntax check + live acceptance run, no bash fixtures).
