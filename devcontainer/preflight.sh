#!/usr/bin/env bash
# preflight.sh — self-verifying checks for the devcontainer environment.
#
# Two modes:
#   preflight.sh host       — run on the WSL2 host: WSL2 kernel, docker
#                             installed + daemon responding, VS Code CLI,
#                             Remote - Containers extension.
#   preflight.sh container  — run inside the container: Copilot CLI present
#                             + version, Tier 1 toolchain (ASE #482), sudo,
#                             LAN reachability to the model server, and
#                             runtime-package drift. Wired as
#                             postCreateCommand so a fresh build proves itself.
#
# Each check prints one PASS/FAIL line. Any FAIL -> non-zero exit.

set -u

MODE="${1:-}"
overall=0

pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; overall=1; }
info() { printf 'INFO  %s\n' "$1"; }   # informational — does not affect exit

case "$MODE" in
  host)
    # 1. WSL2 kernel signature
    if uname -r | grep -q 'microsoft-standard-WSL2'; then
      pass "WSL2 kernel ($(uname -r))"
    else
      fail "WSL2 kernel ($(uname -r))"
    fi

    # 2. docker installed + daemon responding
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
      pass "docker installed + daemon responding"
    else
      fail "docker installed + daemon responding"
    fi

    # 3. VS Code CLI / WSL integration
    #    `code` is only on PATH inside the VS Code WSL terminal: it wraps the
    #    server's remote-cli/code, which needs the live WSL runtime, so it does
    #    not run from a plain SSH shell. From any other shell, fall back to the
    #    integration-presence signal: the VS Code Server is installed in $HOME
    #    (created when VS Code connects to WSL).
    if command -v code >/dev/null 2>&1 && code --version >/dev/null 2>&1; then
      pass "VS Code CLI ($(code --version 2>/dev/null | head -1))"
    elif [ -d "$HOME/.vscode-server" ]; then
      pass "VS Code WSL integration (.vscode-server present)"
    else
      fail "VS Code CLI / WSL integration"
    fi

    # 4. Remote - Containers extension
    #    Lives in the Windows VS Code (or the WSL server). Check both.
    if code --list-extensions 2>/dev/null | grep -q 'ms-vscode-remote.remote-containers'; then
      pass "Remote - Containers extension"
    elif ls /mnt/c/Users/*/.vscode/extensions 2>/dev/null | grep -q 'ms-vscode-remote.remote-containers' \
         || ls "$HOME/.vscode-server/extensions" 2>/dev/null | grep -q 'ms-vscode-remote.remote-containers'; then
      pass "Remote - Containers extension (installed)"
    else
      fail "Remote - Containers extension"
    fi
    ;;

  container)
    # Copilot CLI present + version (must pass — the Dockerfile installs it).
    if command -v copilot >/dev/null 2>&1 && copilot --version >/dev/null 2>&1; then
      pass "Copilot CLI ($(copilot --version 2>/dev/null | head -1))"
    else
      fail "Copilot CLI"
    fi

    # Auth state (informational only — a fresh container is unauthenticated
    # by design; `copilot login` is a one-time step per container). The
    # container has no system keychain, so a stored login lives in
    # ~/.copilot/config.json and persists with the container filesystem.
    if [ -n "${COPILOT_GITHUB_TOKEN:-}" ] || [ -n "${GH_TOKEN:-}" ] || [ -n "${GITHUB_TOKEN:-}" ]; then
      info "Copilot auth: token via environment variable"
    elif [ -f "$HOME/.copilot/config.json" ]; then
      info "Copilot auth: token stored (~/.copilot/config.json)"
    else
      info "Copilot auth: not signed in — run 'copilot login' (device code flow)"
    fi

    # ── Tier 1 toolchain (ASE #482) ── one PASS/FAIL line per tool.
    for tool in git gh jq curl wget ssh python3 pip3 gcc g++ make rg fd \
                vim less man ps lsof fuser pstree strace tree htop file nc \
                zip unzip patch diff dos2unix ip ping openssl tar sudo; do
      if command -v "$tool" >/dev/null 2>&1; then
        pass "tool: $tool"
      else
        fail "tool: $tool"
      fi
    done

    # Passwordless sudo (the runtime-install workflow: sudo apt-get install
    # mid-session, no rebuild).
    if sudo -n true 2>/dev/null; then
      pass "sudo (passwordless)"
    else
      fail "sudo (passwordless)"
    fi

    # gh auth state (informational — auth is not baked in; it comes from the
    # bind-mounted ~/.config/gh, the one-time-per-machine pattern).
    if gh auth status >/dev/null 2>&1; then
      info "gh auth: signed in"
    else
      info "gh auth: not signed in — run 'gh auth login' (or mount ~/.config/gh)"
    fi

    # LAN reachability to the model server (the local-LLM path:
    # COPILOT_PROVIDER_* -> litellm). The endpoint is per-machine: set
    # MODEL_SERVER_URL (e.g. via devcontainer.user.local.json containerEnv).
    # Unset = skip — a check, not an assumption, where you have one.
    server_url="${MODEL_SERVER_URL:-}"
    if [ -z "$server_url" ]; then
      info "model server: MODEL_SERVER_URL not set — skipping reachability check"
    else
      hostport="${server_url#http://}"
      hostport="${hostport%%/*}"
      if curl -s -o /dev/null --max-time 5 "$server_url/models" 2>/dev/null; then
        pass "model server reachable ($server_url)"
      elif (exec 3<>"/dev/tcp/${hostport%%:*}/${hostport##*:}") 2>/dev/null; then
        exec 3>&- 2>/dev/null
        pass "model server TCP reachable ($hostport)"
      else
        fail "model server reachable ($server_url)"
      fi
    fi

    # Runtime-package drift (ASE #482): packages installed at runtime via
    # sudo apt-get, not yet committed to the Dockerfile. Informational — a
    # clean baseline is the common case.
    if [ -f /var/lib/pkg-baseline ]; then
      added="$(comm -13 <(awk '{print $2}' /var/lib/pkg-baseline | sort) \
                       <(dpkg-query -W 2>/dev/null | awk '{print $2}' | sort))"
      if [ -n "$added" ]; then
        info "runtime packages (add to Dockerfile): $(echo "$added" | tr '\n' ' ')"
      else
        info "package baseline: clean (no runtime installs)"
      fi
    fi
    ;;

  *)
    echo "usage: preflight.sh {host|container}" >&2
    exit 2
    ;;
esac

exit "$overall"
