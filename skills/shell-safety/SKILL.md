---
name: shell-safety
description: Safety rules for shell commands. Must be consulted before any destructive or irreversible shell command.
version: 1.0.0
---

These rules apply unconditionally to every shell command, in every session, including subagent sessions with no confirmation UI. Where a destructive-command guard exists, it is a backstop, not a substitute for these rules.

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
- Avoid immediate destructive commands: move files to a temporary directory so that mistakes are recoverable.
- Insert safety warnings: If a requested command cannot be made fully safe via expansion guards, prepend a clear comment explaining the risk before the command.
