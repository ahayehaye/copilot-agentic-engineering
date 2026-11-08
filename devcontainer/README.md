# Copilot devcontainer

A reproducible devcontainer (VS Code + WSL2 + Docker) that provisions a
sandboxed environment running **Copilot in both forms** — the Copilot CLI
agent and the VS Code Copilot extension.

The load-bearing constraint: as much logic as possible lives in the
`Dockerfile` + `devcontainer.json`, so the build reproduces cleanly from
scratch on a second machine.

This README is the process doc. Rhythm: **do the step → run the check that
proves it → next step.** A second machine follows this top to bottom.

## Layout

- `.devcontainer/devcontainer.json` — opening this folder in VS Code triggers
  the build
- `Dockerfile`
- `preflight.sh` — self-verifying checks (`host` / `container` modes)
- `README.md` — this file

## Host layer

The host is a WSL2 distro with Docker. These steps run on the host, not in
the container.

### 1. Install Docker

```bash
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl enable --now docker
```

On Debian 13 (trixie) this installs `docker.io 26.1.5` and creates the
`docker.service` + `docker.socket` symlinks. The daemon starts under systemd.

**Your WSL user needs the docker group** (or every `docker` call needs
`sudo`). Use the distro's default user — the one VS Code connects as. On a
fresh box:

```bash
sudo usermod -aG docker <your-wsl-user>
```

Group changes take effect on the **next login session** — open a new shell
before the check below.

**Check:** the daemon responds.

```bash
docker run --rm hello-world
```

Real output (tiger-wsl, 2026-11-05):

```
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

### 2. Verify the host layer

```bash
./preflight.sh host
```

All four checks PASS once steps 1 and 3 are done. The check is robust to the
shell context: `code` is only on PATH inside the VS Code WSL terminal (it
wraps the server's `remote-cli/code`, which needs the live WSL runtime), so
the preflight falls back to the integration-presence signal (`.vscode-server`
in `$HOME`) and checks the Windows VS Code extensions dir for Remote -
Containers. That means it passes from any shell — including a plain SSH
session — and reproduces on a second machine.

Real output (tiger-wsl, 2026-11-05, as the default WSL user):

```
PASS  WSL2 kernel (6.18.54.1-microsoft-standard-WSL2)
PASS  docker installed + daemon responding
PASS  VS Code WSL integration (.vscode-server present)
PASS  Remote - Containers extension (installed)
```

### 3. Install VS Code + Remote - Containers

VS Code runs on the **Windows host** and connects into WSL (and, via Remote
- Containers, into the container). Same shape on the work laptop.

**3a. Install VS Code on Windows** — the one step that isn't a shell command.
Download from https://code.com and run the installer.

**3b. Connect to WSL** — in VS Code, open the Command Palette
(`Ctrl+Shift+P`) and connect to the WSL distro (Remote Explorer → the WSL
target → *Connect to WSL*). This installs the VS Code Server into the distro
(`~/.vscode-server`) and makes the `code` CLI available in the WSL terminal.

**3c. Install the Remote - Containers extension** — in VS Code, install
`ms-vscode-remote.remote-containers` (the "Dev Containers" extension). It
lives in the Windows VS Code and orchestrates the container build.

**Check:** the integration is active and the extension is installed.

```bash
ls ~/.vscode-server >/dev/null 2>&1 && echo "WSL integration: OK"
ls "/mnt/c/Users/$USER/.vscode/extensions" 2>/dev/null | grep remote-containers
```

Real output (tiger-wsl, 2026-11-05):

```
WSL integration: OK
ms-vscode-remote.remote-containers-0.469.0
```

**3d. Tell Dev Containers where docker lives** — in VS Code user settings
(`Ctrl+,` → JSON):

```json
"dev.containers.executeInWSL": true,
"dev.containers.executeInWSLDistro": "Debian"
```

Why: the repos dir is a **Windows drive** (a VBox share at
`/mnt/d/vbox/shared/vscode`), and the Dev Containers extension's default is
to "only execute in WSL for workspace folders in WSL" — a folder under
`/mnt/<drive>` counts as Windows, so it looks for docker on the Windows
PATH and fails with `Executable 'docker' not found`. These settings force
the CLI into the WSL distro, where `docker.io` lives. They are
**application-scoped** (user settings only — workspace settings are
ignored), so this is a one-time per-machine step. Settings Sync carries
it to a second machine automatically if you use it.

## Container layer

The container layer is the `Dockerfile` + `devcontainer.json`. The
`Dockerfile` installs the Copilot CLI via the official script
(`https://gh.io/copilot-install`) and creates a `dev` user whose uid
matches the WSL host user (build args `DEV_UID`/`DEV_GID`, default 1000 —
the first-user uid on a fresh distro). `devcontainer.json` adds the
`github.copilot` VS Code extension, bind-mounts the centralized repos dir
and a host-side `~/.copilot` (so sign-in survives rebuilds), opens the
repo root, and wires `preflight.sh container` as `postCreateCommand`, so a
fresh build proves itself.

### 4. Reopen the folder in the container

Open the `devcontainer/` folder in a VS Code window connected to the WSL
distro (the green `WSL: <distro>` badge, bottom-left). VS Code detects
`.devcontainer/devcontainer.json` and offers the build.

**Known quirk (VS Code 1.145, 2026-11-05):** the
`Dev Containers: Reopen in Container` command is *hidden from the command
palette* in 1.145 — the core workbench suppresses the extension's
connect-family commands (all of them carry a `hideConnectCommands` guard)
and surfaces the flow as a notification instead. The command itself is
alive: the core's own Remote Explorer "Dev Container" entry invokes the
same `remote-containers.reopenInContainer`.

So the reliable paths are, in order:

1. **The reopen notification** — bottom-right, when the folder with
   `.devcontainer/` is open. If you previously dismissed it with
   "don't show again", first run
   `Dev Containers: Reset Don't Show Reopen Notification`, then reopen
   the folder.
2. **Remote Explorer** — the `WSL: <distro>` target → the **Dev
   Container** entry.

**Check:** the window title and status bar show the container, and the
terminal shows `postCreateCommand` running the container preflight.

Two things to expect:

- The window opens at the **repo root**
  (`copilot-agentic-engineering`), not the `devcontainer/` subfolder —
  that's `workspaceFolder` doing its job.
- VS Code warns that **performance may be degraded** — the standard notice
  for a workspace on a Windows drive (9p). Expected, harmless for this use.

Real output (tiger-wsl, 2026-11-05, first build):

```
Running the postCreateCommand from devcontainer.json...

[16509 ms] Start: Run in container: /bin/sh -c ./preflight.sh container
PASS  Copilot CLI (GitHub Copilot CLI 1.0.105.)
INFO  Copilot auth: not signed in — run 'copilot login' (device code flow)
Done. Press any key to close the terminal.
```

### 5. Sign in to the Copilot CLI (one-time, per machine)

In a container terminal:

```bash
copilot login
```

The container is a known headless environment, so the CLI defaults to the
**device code flow**: it prints a one-time code and polls. Enter the code
at `https://github.com/login/device` in your browser (the Windows host),
authorize, and the terminal completes.

Real output (tiger-wsl, 2026-11-05):

```
To authenticate, visit https://github.com/login/device and enter code 89A6-CE23
Waiting for authorization...
Failed to open browser. Please visit https://github.com/login/device and enter the code 89A6-CE23 manually.
```

(after authorizing in the browser: `Signed in successfully`)

**Where the token lives.** The container has no system keychain
(libsecret), so the CLI stores the OAuth token in a plaintext file at
`~/.copilot/config.json` (mode 600). `devcontainer.json` bind-mounts a
host-side `~/.copilot` over the container's, so the token lives on the WSL
filesystem — **login is one-time per machine**, and even a full
tear-down/rebuild comes back signed in.

**Check:** the preflight reports the stored token, before and after a
container restart — and after a full rebuild (see below).

Real output (tiger-wsl, 2026-11-05, after `docker restart`):

```
PASS  Copilot CLI (GitHub Copilot CLI 1.0.105.)
INFO  Copilot auth: token stored (~/.copilot/config.json)
```

### Persistence: mounts and the matching-uid user

The container is a sandbox over your real repos, not a copy of them:

- **Repos dir bind-mounted** — the centralized projects dir
  (`/mnt/d/vbox/shared/vscode` on the home box) is mounted at
  `/workspaces/vscode`. Edits in the container land in the WSL-side
  checkout directly; there is no sync step. All your projects are
  reachable from the sandbox.
- **`~/.copilot` bind-mounted** — the token (and CLI state) persist on the
  host across rebuilds.
- **`~/.ssh` bind-mounted** — ssh keys + known_hosts for remote box work;
  sessions and keys persist across rebuilds.
- **`~/.config/gh` bind-mounted** — `gh` auth state; one-time-per-machine,
  same pattern as `~/.copilot`.

**Mount sources must exist on the host.** Docker refuses to start the
container if a bind source path is missing (`bind source path does not
exist`). On a fresh machine, before the first build:

```bash
mkdir -p ~/.copilot ~/.config/gh && chmod 700 ~/.copilot ~/.config/gh
```

(`~/.ssh` exists by default.) Create them as your user — a root-created
dir becomes a root-owned mount and the container's writes land
root-owned on the host.
- **Matching-uid user** — the Dockerfile creates `dev` with the host uid
  (`DEV_UID`/`DEV_GID` build args, default 1000), so files the container
  writes into the bind mounts are host-owned, and git doesn't refuse the
  repos with "dubious ownership". `postCreateCommand` adds a
  `safe.directory '*'` guard as insurance for the case where the uids
  don't match (the container is a sandbox; the repos are yours).

**The rebuild proof** (2026-11-05): container + images removed, then
`devcontainer up` from the files alone. The container came up with all
three mounts, as `dev`, and the preflight reported the token already
stored — no re-login:

```
--mount type=bind,source=/mnt/d/vbox/shared/vscode/agentic-software-engineering,target=/workspaces/agentic-software-engineering
--mount source=/mnt/d/vbox/shared/vscode,target=/workspaces/vscode,type=bind
--mount source=/home/alexh/.copilot,target=/home/dev/.copilot,type=bind
... -u dev ...

PASS  Copilot CLI (GitHub Copilot CLI 1.0.105.)
INFO  Copilot auth: token stored (~/.copilot/config.json)
```

A live prompt through the migrated token confirmed it authenticates
(`copilot -p "Reply with exactly: ok"` → `ok`).

**Per-machine values.** The committed `devcontainer.json` carries the
common shape (uid 1000, home-box paths). A machine that differs overrides
`build.args` + `mounts` in a **`devcontainer.user.local.json`** next to
`devcontainer.json` (gitignored; it merges over the committed file). The
only values that should ever differ are the uid, the four mount
sources (repos dir, `~/.copilot`, `~/.ssh`, `~/.config/gh` paths), and
`MODEL_SERVER_URL` (via `containerEnv`) — the model-server endpoint the
preflight reachability check uses; unset skips the check.

### 6. (Fallback) Authenticate with a token env var

If the device code flow misbehaves — the known WSL2 flake is
[github/copilot-cli#1112](https://github.com/github/copilot-cli/issues/1112):
device-code polling hangs because WSL2's monotonic clock ticks faster than
real time, driving a `slow_down` loop (fixed in later CLI releases; we
install latest, 1.0.105 at the time of writing) — use a token env var
instead. The CLI checks, in order: `COPILOT_GITHUB_TOKEN`, `GH_TOKEN`,
`GITHUB_TOKEN`.

The token must be a **fine-grained PAT** (prefix `github_pat_`) owned by
your *personal* account with the **Copilot Requests** account permission.
Classic `ghp_` PATs are not supported.

```bash
export COPILOT_GITHUB_TOKEN=github_pat_...
```

An env var silently overrides a stored `copilot login` token — unset it to
go back to the stored login.

### Daily-driver toolchain (ASE #482)

The Dockerfile carries the full Tier 1 toolchain, not a bare minimum: the
package list is grounded in the fizban dev-box scan (same Debian 13 base)
plus two weeks of observed session / bash-history usage. Core (git, gh,
jq, curl, wget), remote work (openssh-client), python3 + venv + pip + dev,
build-essential (native python builds), ripgrep + fd, vim/less/man-db/manpages,
process debugging (procps, lsof, psmisc incl. pstree, strace), inspection
(tree, htop, file, netcat-openbsd), archives (incl. zip + unzip),
diff/patch, network (iproute2, iputils-ping), openssl, and QoL (locales,
bash-completion, apt-file). The system/GUI layer is deliberately excluded —
the container stays headless. `tmux` is out by design (session persistence
fights the ephemeral-sandbox identity; separate ops-environment work).

**Runtime installs (sudo + drift check).** A discovered package should cost
a 10-second install, not a rebuild:

1. `sudo apt-get update && sudo apt-get install pkg` — the `dev` user has
   passwordless sudo (sudoers drop-in in the Dockerfile).
2. Keep working.
3. The preflight drift check (or `comm -13` against
   `/var/lib/pkg-baseline`) names the uncommitted package.
4. Commit it to the Dockerfile; the next rebuild is clean and the drift
   line reads `package baseline: clean`.

**Naming and the forklift.** This is ASE's *testbed* container —
`ase-devcontainer` / container name `ase-dev`. The forklift carries
`devcontainer/` to `copilot-agentic-engineering` as-is; the rinse pass
strips the upstream agent layer and renames it `copilot-devcontainer` /
`copilot-dev` — that name belongs to the public repo, where the
devcontainer is canonical. Work repos ingest from there. Both
containers can run side-by-side: Dev Containers scopes by workspace
folder, and the shared mounts (`~/.copilot`, `~/.ssh`, `~/.config/gh`,
the repos dir) are per-user state, correct to share.

**Local-LLM path.** The `COPILOT_PROVIDER_*` env points at the litellm
endpoint, working from inside the container. The preflight checks LAN
reachability to the model server named by `MODEL_SERVER_URL` (per-machine,
see above) — a check, not an assumption.

## The VS Code Copilot extension

`devcontainer.json` installs `github.copilot` into the container's VS Code
server on create. Its sign-in is separate from the CLI's: it uses VS Code's
own GitHub account flow (the account you're signed in with in the editor).
Both forms of Copilot are then available: the CLI in the terminal, the
extension in the editor. Verified 2026-11-05: chat prompt in the container
window answered (`Reply with exactly: ok` → `ok`).

## Reproduce on a second machine

The work laptop is the same shape: Windows + WSL2 + `docker.io` + VS Code.
From a `git clone` of this repo, top to bottom:

1. **Host layer** — steps 1–3d above: `docker.io` + docker group, VS Code
   + WSL integration + Dev Containers extension, and the two
   `dev.containers.executeInWSL*` user settings (Settings Sync carries
   them if you use it). Verify with `./preflight.sh host`.
2. **Reopen** — open the `devcontainer/` folder in a WSL window → the
   reopen notification (or Remote Explorer → Dev Container). The build
   runs; `postCreateCommand` prints the green preflight.
3. **Sign in once** — `copilot login` in a container terminal, device code
   in your browser. The token lands in the host-side `~/.copilot` and
   survives every future rebuild on that machine.
4. **If the machine differs** (uid, repos dir location) — add a
   `devcontainer.user.local.json` with the overridden `build.args` +
   `mounts`, as described in the persistence section.

That's the whole setup. Everything else is in the files.
