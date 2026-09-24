# ADR-0022: The Manifest Boundary Is the Clobber Protection

**Date**: 2026-09-24
**Status**: Accepted
**Issue**: [#77](https://github.com/ahayehaye/copilot-agentic-engineering/issues/77)

## Context

The ledger target (see [ADR-0021](0021-ledger-target-is-a-generated-artifact.md)) holds work content — tickets, research, memory — that is **not under revision control by any remote**. An inadvertent overwrite or deletion is catastrophic. The manager must be able to re-run safely after the lab's scaffolding evolves, with user content sitting in the same directories.

## Decision

The manifest boundary is the clobber protection.

- **The manifest** (`ledger/manifest.json`) lists the exact scaffolding files. A manifest file present in the target is **never overwritten**: install-if-missing + drift warning (with a unified diff); `--reinstall` is the only adoption path (timestamped sibling backup, then replace).
- **Files not in the manifest — all user content — are never touched by any command.** Any command that can touch a non-manifest file is a defect.
- **The local-git backstop** complements the manifest: `deploy` runs `git init` in the target (if not already a repo) and makes an initial commit of the deployed scaffolding. The manager never auto-commits user content; `upgrade` reports uncommitted user content as an advisory ("N user-content files changed since last deploy; commit them yourself") without ever committing it.
- **The manager's bookkeeping lives outside the target.** Per-file state dotfiles and reinstall backups are written to the sibling `<target>.backups/` directory (ADR-0003), never inside the target. The target's write surface is exactly the manifest files; "never touched" refers to user content — the manager's own bookkeeping in the sibling directory is not user content.

## Considered Options

- **Version-gated lifecycle (as in `skill-manager.sh`).** Rejected for this target — it upgrades in place and would clobber user edits to scaffolding files; the target's content is user-owned, not item-owned.
- **Manifest boundary + local-git backstop.** Chosen — the manifest makes the manager's write surface exactly the scaffolding, and the local repository makes any residual mistake recoverable.

## Consequences

- **Positive**: Re-runs are safe by construction; adoption of a changed scaffolding file is explicit and reversible (timestamped sibling backup).
- **Positive**: The manager's write surface is inspectable (`list`) and bounded — a new scaffolding file is added to the manifest, and nothing else.
- **Negative**: A scaffolding file the user hand-edited is reported as drift, never silently re-synced. Accepted: deliberate adoption via `--reinstall` is the point.
- **Neutral**: The drift helpers (content hash, three-way classification, drift diff) are reused from `agent-manager-lib.sh` (ADR-0007); backups are siblings of the target (ADR-0003).
