## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context repo — one `CONTEXT.md` and `docs/adr/` at the root. See `docs/agents/domain.md`.

## Bash

- Use safe bash formulations so a command never hits the destructive-command guard.
- Delete an empty directory with `rmdir`.
- Delete a single file with `rm <file>` and no recursive flags.
- Never use `sudo`.
- Never use `chmod` or `chown` with `777`.
- A recursive delete is only allowed when it is truly unavoidable.
- For an unavoidable recursive delete, delete the contents one file at a time, then run `rmdir` on the directory.
- When the contents cannot be recreated, back the target up to a sibling file first.
- Do not substitute another command (for example `find -delete`) to bypass the guard.
- If a destructive command cannot be made safe, report it to the user instead of running it.

## Testing

- Unit tests for Python code are expected.
- Do not write tests for bash scripts, anywhere in this repo.
- **Do not attempt fixture dry-runs for bash scripts** (temporary HOME, stubbed binaries, fake PATH). These are unreliable in agent execution — PATH manipulation on Windows/Git Bash is fragile, workers hallucinate paths, and each fixture wastes 10+ minutes. Verify bash scripts with `bash -n` (syntax), `bash -x` (trace on the real machine), and live acceptance runs instead.
