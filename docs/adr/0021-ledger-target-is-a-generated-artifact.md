# ADR-0021: The Ledger Target Is a Generated Artifact, One-Way from the Lab

**Date**: 2026-09-24
**Status**: Accepted
**Issue**: [#77](https://github.com/ahayehaye/copilot-agentic-engineering/issues/77)

## Context

The work laptop runs a personal, multi-namespace ticketing + research + memory environment. The lab (this repo) authors the scaffolding; the work content (tickets, research, memory) lives in a user-chosen target directory (e.g. OneDrive), unversioned by any remote. The open design question is where the work content lives relative to the lab.

## Decision

The ledger target is a generated artifact, one-way from the lab. The lab is the source; the target is generated; `scripts/ledger-manager.sh` is the only road between them. The target is a local git repository (no remote, ever) as a backstop; the manager never pushes, adds remotes, or edits `.git/config` beyond `git init`.

- **The skeleton is authored in the lab** under `ledger/`; the manager deploys it to the target.
- **Re-runs are safe by construction**: a manifest lists the exact scaffolding files; manifest files are install-if-missing with drift warnings (never clobbered); every other file in the target — all user content — is never touched.
- **Global skills are checked and warned on, never installed or upgraded** by the ledger manager; `skill-manager.sh` remains the sole owner of the global skill lifecycle.

## Considered Options

- **In-repo `work/` subtree.** Rejected — private content would live in a repo with a public face (the public forklift), and the lab's churn lifecycle would sit next to content that needs stability.
- **A dedicated second repo.** Rejected — a second repo is attention debt, and skills would need syncing instead of being native.
- **Generated artifact, one-way from the lab.** Chosen — the lab stays authored, the target stays generated, and the deploy script is the single, inspectable road between them.

## Consequences

- **Positive**: Work content never mixes with the lab's public face; the target's local git repository gives every file version history and makes an inadvertent overwrite recoverable.
- **Positive**: "What's in here?" is a one-liner (`status`), and redeploy is a no-brainer (the `deployed-from` marker records the lab commit).
- **Negative**: The target has no remote — it is not backed up beyond the local repository and any user-side sync (e.g. OneDrive). Accepted: remote sync of any kind is deliberately out of scope.
- **Neutral**: The `deployed-from` marker and the manifest are the audit trail for the one-way sync.
