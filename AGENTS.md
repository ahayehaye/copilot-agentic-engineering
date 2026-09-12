## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues. See `docs/agents/issue-tracker.md`.

<!-- setup-alex-skills:label-rule -->
**Label rule (overrides skill defaults):** when publishing via `/to-spec` or `/to-tickets`, apply the label application rule in `docs/agents/issue-tracker.md` — specs get `spec`, slices get `vertical-slice`. The skills' default `ready-for-agent` label may be added but never replaces them.
<!-- /setup-alex-skills:label-rule -->

### Domain docs

Single-context repo — one `CONTEXT.md` and `docs/adr/` at the root. See `docs/agents/domain.md`.

When doing potentially risky or dangerous actions with the shell, always consult the shell-safety skill.

## Testing

- Unit tests for Python code are expected.
- Do not write tests for bash scripts, anywhere in this repo.
- **Do not attempt fixture dry-runs for bash scripts** (temporary HOME, stubbed binaries, fake PATH). These are unreliable in agent execution — PATH manipulation on Windows/Git Bash is fragile, workers hallucinate paths, and each fixture wastes 10+ minutes. Verify bash scripts with `bash -n` (syntax), `bash -x` (trace on the real machine), and live acceptance runs instead.
