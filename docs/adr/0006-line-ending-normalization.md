# ADR-0006: Line Ending Normalization

**Date**: 2026-08-29
**Status**: Accepted

## Context

This working tree is shared and checked out on both Windows (via Git Bash) and Linux, and it is entirely text — Markdown, shell, Python, TypeScript, JSON, TOML, and configuration files. No file in the repo is binary or Windows-specific, so every file is subject to the line endings of whatever machine and editor wrote it.

The project already pins shell and Python scripts to LF (`*.sh text eol=lf` and `*.py text eol=lf`, introduced in #126). That rule left every other text extension unprotected: a Markdown, JSON, or TOML file arriving with CRLF from a co-worker's Windows machine would not be normalized, and the shared tree could drift to mixed line endings. Because the tree is shared and rechecked out on machines with different native line endings, "scripts only" was not enough to guarantee a single, consistent line ending everywhere.

## Decision

Adopt a single catch-all rule in `.gitattributes`:

```
* text=auto eol=lf
```

This pins **every** text file to LF. The two tokens do distinct work:

- **`text=auto`** marks each file as text and makes git normalize CRLF → LF when the file is *committed*, so the repository never stores a CR byte.
- **`eol=lf`** forces LF on *checkout*, so the working tree stays LF on every machine regardless of its native line ending.

Because an explicit `.gitattributes` rule wins over global git config, this pin overrides `core.autocrlf` on every machine — a developer with `core.autocrlf=true` set globally still commits and checks out LF.

## Considered Options

- **Scripts-only pin** (`*.sh text eol=lf`, `*.py text eol=lf`). Rejected — it covered only the files that existed under the rule and left Markdown, JSON, TOML, and every future text extension free to carry CRLF, which is exactly how a shared tree drifts.
- **`text=true` without `eol=lf`.** Rejected — `text=true` normalizes only on commit; checkout would then use the machine's native line ending, so a Windows checkout would reintroduce CRLF into the working tree and defeat the pin.
- **`* binary` with per-extension text exceptions.** Rejected — it inverts the default for an all-text repo, disables git normalization and diffing for every file, and requires enumerating each text extension by hand, which is brittle as new file types are added.

## Consequences

- **Positive**: One catch-all rule is the single source of truth — no per-extension table to maintain, and no text file falls through the cracks.
- **Positive**: The repository never stores CRLF and every working tree is LF, independent of OS or the developer's global `core.autocrlf` setting.
- **Positive (no-op today)**: Zero tracked files currently contain a CR byte, and the repo has no binary or Windows-specific files, so this pin rewrites nothing and produces no line-ending churn on merge.
- **Positive (runtime companion guard)**: `scripts/agent-manager-lib.sh` carries a defensive on-disk guard that does not depend on the pin. Its `extract_version()` function strips a trailing CR from every line while scanning YAML frontmatter (`line="${line%$'\r'}"  # Strip trailing CR for CRLF files`) and from the Python/TypeScript header-comment fallbacks via `sed 's/\r$//'`. Future implementers should rely on this guard rather than duplicate it, and should not remove it as a redundancy — it is the backstop that keeps version extraction correct if a file ever lands on disk with CRLF despite the `.gitattributes` pin.
- **Negative**: New files must be authored with LF; this is handled automatically by editors and by git's checkout normalization, so it is only a concern for files introduced outside of git.
