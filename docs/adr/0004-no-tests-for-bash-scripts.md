# ADR-0004: No Tests, Fixtures, or Fixture Dry-Runs for Bash Scripts

**Date**: 2026-08-28
**Status**: Accepted

## Context

This project contains bash manager scripts (`skill-manager.sh`, `mcp-manager.sh`, `copilot-agent-manager.sh`) that are executed via Git Bash on Windows. During the manager implementation, fixture dry-runs were specified as the verification method — temporary HOME directories with stubbed binaries on PATH, designed to simulate install/upgrade/skip decisions without touching the real system.

Fixture dry-runs proved unworkable in agent execution:

- **PATH manipulation on Windows/Git Bash is fragile** — stubbing external commands requires temp directories, fake binaries, and careful PATH scoping that breaks across tool calls.
- **Workers hallucinate paths** (e.g., `C:\Users\runneradmin`) when creating temp environments, producing non-recoverable errors.
- **Each fixture wastes 10+ minutes of agent time** — a single slice that should take 5 minutes of implementation spirals into 30+ minutes of debugging fixture setup.
- **The setup is single-user and idempotent** — the live acceptance run covers all real-world scenarios and is sufficient verification.

## Decision

**Do not write tests, fixtures, or fixture dry-runs for bash scripts in this project.** This applies to:

- Unit tests (no test files for `.sh` scripts)
- Integration test fixtures (no `test_fixtures/` directories with stubbed binaries)
- Fixture dry-runs (no temporary HOME, fake PATH, or mock command environments)

Bash scripts are verified through:

1. **Syntax check**: `bash -n scripts/<script>.sh`
2. **Trace on the real machine**: `bash -x scripts/<script>.sh --dry-run <command> 2>&1 | tail -20`
3. **Live acceptance run**: One real execution on the developer's machine as the integration test

Python code continues to require unit tests as normal.

## Considered Options

- **Fixture dry-runs with stubbed binaries.** Rejected — unreliable in agent execution, wastes time, and the live acceptance run covers the same scenarios more faithfully.
- **ShellCheck or similar static analysis.** Not rejected — could be added later as a lint step — but does not replace the need to eliminate fixture-based testing.
- **No verification at all.** Rejected — syntax checks and live runs provide sufficient confidence without the fixture overhead.

## Consequences

- **Positive**: Slices complete in minutes instead of tens of minutes. Agent execution is reliable and predictable.
- **Positive**: Verification matches how the scripts are actually used — on the real machine, with real tools, against real state.
- **Negative**: No isolated test environment means verification touches the real system. Mitigated by `--dry-run` modes and idempotent, backup-protected operations.
- **Neutral**: The live acceptance run (per feature) is the integration test. This is explicit and documented, not implicit.
