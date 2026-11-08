## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues. See `docs/agents/issue-tracker.md`.

<!-- setup-alex-skills:label-rule -->
**Label rule (overrides skill defaults):** when publishing via `/to-spec` or `/to-tickets`, apply the label application rule in `docs/agents/issue-tracker.md` — specs get `spec`, slices get `vertical-slice`. The skills' default `ready-for-agent` label may be added but never replaces them.
<!-- /setup-alex-skills:label-rule -->

### Domain docs

Single-context repo — one `CONTEXT.md` and `docs/adr/` at the root. See `docs/agents/domain.md`.

When doing potentially risky or dangerous actions with the shell, always consult the shell-safety skill.

## Credentials (hard rule)

**Never commit credentials.** API keys, tokens, and passwords live in
per-install, gitignored files or environment variables, never in committed
templates, configs, or code. A committed file may name *where* a secret
lives (a `.example` with a placeholder value) but never the value itself.

Enforcement: `bash scripts/check-secrets.sh` scans staged changes for
credential patterns (token prefixes, key/value pairs with real-looking
values). Run it before every commit — a match blocks the commit until the
secret moves to a gitignored file or env var.

## Testing

- Unit tests for Python code are expected.
- TypeScript: test the pure module directly with Node's built-in test runner — `node --test <file>.test.ts` (type stripping, no package manifest, no dependencies, no build step). Requires Node >= 23.6. Example: `some-module/decision.test.ts` (a pure module beside the code under test).
- Do not write tests for bash scripts, anywhere in this repo.
- **Do not attempt fixture dry-runs for bash scripts** (temporary HOME, stubbed binaries, fake PATH). These are unreliable in agent execution — PATH manipulation on Windows/Git Bash is fragile, workers hallucinate paths, and each fixture wastes 10+ minutes. Verify bash scripts with `bash -n` (syntax), `bash -x` (trace on the real machine), and live acceptance runs instead.
