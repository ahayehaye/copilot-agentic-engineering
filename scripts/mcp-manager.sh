#!/usr/bin/env bash
#
# mcp-manager.sh — Install, upgrade, and uninstall MCP servers
#
set -euo pipefail

# ─── Source shared library ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/agent-manager-lib.sh"

# ─── MCP-specific directories ─────────────────────────────────────────────────
SOURCE_DIR="${SCRIPT_DIR}/../mcp-servers"
TARGET_DIR="$HOME/.agents/mcp"
BACKUP_DIR="$HOME/.agents/mcp.backups"
VENV_DIR="$TARGET_DIR/.venv"
MCP_CONFIG_FILE="$HOME/.copilot/mcp-config.json"

# ─── MCP-specific usage ───────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage: mcp-manager.sh <command> [options] [args]

Commands:
  install <server-name>         Install or upgrade an MCP server
  install-all                   Install all MCP servers from source
  upgrade <server-name>         Alias for install <server-name>
  upgrade-all                   Upgrade installed MCP servers with newer source versions
  uninstall <server-name>       Remove an installed MCP server
  list                          Show installed MCP servers with versions
  list-available                Show MCP servers available in source
  status                        Compare installed vs available (outdated/new)

Options:
  --reinstall, -f               Force reinstall even if version matches
  --dry-run, -n                 Preview changes without making them
  --source <path>               Override auto-detected mcp-servers/ directory
  --help, -h                    Show usage
EOF
}

# ─── Helpers ──────────────────────────────────────────────────────────────────

# Find the entry-point .py file (first alphabetically) in a server directory.
find_entrypoint() {
  local dir="$1"
  local py
  py="$(ls -1 "$dir"/*.py 2>/dev/null | head -1)"
  echo "$py"
}

# ─── Virtualenv & dependency helpers ──────────────────────────────────────────

ensure_venv() {
  if [[ ! -d "$VENV_DIR" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo -e "  ${BLUE}[dry-run]${RESET} Would create virtualenv at $VENV_DIR"
    else
      python -m venv "$VENV_DIR"
      echo -e "  ${BLUE}Created virtualenv at $VENV_DIR${RESET}"
    fi
  fi
}

# Detect the venv's binary directory (bin/ on Unix, Scripts/ on Windows)
get_venv_bin() {
  if [[ -d "$VENV_DIR/bin" ]]; then
    echo "$VENV_DIR/bin"
  elif [[ -d "$VENV_DIR/Scripts" ]]; then
    echo "$VENV_DIR/Scripts"
  else
    echo "$VENV_DIR/bin"
  fi
}

install_dependencies() {
  local server="$1" src="$2"
  local req="$src/requirements.txt"
  if [[ ! -f "$req" ]]; then
    echo -e "  ${YELLOW}No requirements.txt for $server, skipping pip install${RESET}"
    return 0
  fi
  local venv_bin
  venv_bin="$(get_venv_bin)"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "  ${BLUE}[dry-run]${RESET} Would run: ${venv_bin}/pip install -r $req"
    return 0
  fi
  "${venv_bin}/pip" install -r "$req" || {
    echo -e "  ${YELLOW}Warning: pip install failed for $server (fix manually)${RESET}"
    return 0
  }
}

get_venv_python() {
  local venv_bin
  venv_bin="$(get_venv_bin)"
  if [[ -f "$venv_bin/python" ]]; then
    echo "$venv_bin/python"
  elif [[ -f "$venv_bin/python.exe" ]]; then
    echo "$venv_bin/python.exe"
  else
    local py
    py="$(find "$venv_bin" -name 'python*' -type f 2>/dev/null | head -1)"
    echo "${py:-python}"
  fi
}

# ─── mcp-config.json helpers ──────────────────────────────────────────────────

update_mcp_config_add() {
  local server="$1" entrypoint="$2" venv_python="$3"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "  ${BLUE}[dry-run]${RESET} Would add '$server' to $MCP_CONFIG_FILE"
    return 0
  fi

  local config_dir
  config_dir="$(dirname "$MCP_CONFIG_FILE")"
  mkdir -p "$config_dir"
  if [[ ! -f "$MCP_CONFIG_FILE" ]]; then
    echo '{}' > "$MCP_CONFIG_FILE"
  fi

  python -c "
import json, sys
path = sys.argv[1]
server = sys.argv[2]
entrypoint = sys.argv[3]
venv_python = sys.argv[4]

with open(path, 'r') as f:
    config = json.load(f)

config.setdefault('mcpServers', {})[server] = {
    'command': venv_python,
    'args': [entrypoint],
    'transport': 'stdio',
    'tools': ['*']
}

with open(path, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')
" "$MCP_CONFIG_FILE" "$server" "$entrypoint" "$venv_python" || {
    echo -e "${RED}Error: Failed to update $MCP_CONFIG_FILE${RESET}"
    return 1
  }
  echo -e "  ${BLUE}Updated $MCP_CONFIG_FILE with '$server'${RESET}"
}

update_mcp_config_remove() {
  local server="$1"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "  ${BLUE}[dry-run]${RESET} Would remove '$server' from $MCP_CONFIG_FILE"
    return 0
  fi

  if [[ ! -f "$MCP_CONFIG_FILE" ]]; then
    return 0
  fi

  python -c "
import json, sys
path = sys.argv[1]
server = sys.argv[2]

with open(path, 'r') as f:
    config = json.load(f)

mcp_servers = config.get('mcpServers', {})
if server in mcp_servers:
    del mcp_servers[server]

with open(path, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')
" "$MCP_CONFIG_FILE" "$server" || {
    echo -e "${RED}Error: Failed to update $MCP_CONFIG_FILE${RESET}"
    return 1
  }
  echo -e "  ${BLUE}Removed '$server' from $MCP_CONFIG_FILE${RESET}"
}

# ─── Commands ─────────────────────────────────────────────────────────────────

cmd_install() {
  local server="$1"
  local src="$SOURCE_DIR/$server"
  local tgt="$TARGET_DIR/$server"

  if [[ ! -d "$src" ]]; then
    echo -e "${RED}Error: MCP server '$server' not found in source: $src${RESET}"
    exit 1
  fi

  local entrypoint
  entrypoint="$(find_entrypoint "$src")"
  if [[ -z "$entrypoint" || ! -f "$entrypoint" ]]; then
    echo -e "${RED}Error: No .py entrypoint found for server '$server'${RESET}"
    exit 1
  fi

  local src_ver
  src_ver="$(extract_version "$entrypoint")"

  if [[ -d "$tgt" ]]; then
    local tgt_entrypoint
    tgt_entrypoint="$(find_entrypoint "$tgt")"
    local tgt_ver="0.0.0"
    if [[ -n "$tgt_entrypoint" && -f "$tgt_entrypoint" ]]; then
      tgt_ver="$(extract_version "$tgt_entrypoint")"
    fi

    if [[ "$src_ver" == "$tgt_ver" && $FORCE -eq 0 ]]; then
      LAST_ACTION="skipped"
      echo -e "${GREEN}✓${RESET} $server ${CYAN}$tgt_ver${RESET} — already up to date, skipping"
      return 0
    fi

    if semver_gt "$src_ver" "$tgt_ver"; then
      echo -e "${YELLOW}→${RESET} Upgrading $server ${CYAN}$tgt_ver${RESET} → ${CYAN}$src_ver${RESET}"
      do_upgrade "$server" "$src" "$tgt" "$src_ver" "$tgt_ver"
      LAST_ACTION="upgraded"
    elif [[ $FORCE -eq 1 && ( $UPGRADE_ONLY -eq 0 || "$src_ver" == "$tgt_ver" ) ]]; then
      echo -e "${YELLOW}→${RESET} Force reinstalling $server ${CYAN}$tgt_ver${RESET} → ${CYAN}$src_ver${RESET}"
      do_upgrade "$server" "$src" "$tgt" "$src_ver" "$tgt_ver"
      LAST_ACTION="upgraded"
    else
      if [[ $UPGRADE_ONLY -eq 1 ]]; then
        LAST_ACTION="skipped"
        echo -e "${YELLOW}⚠${RESET} WARNING: $server source ${CYAN}$src_ver${RESET} is older than installed ${CYAN}$tgt_ver${RESET} — skipping"
        return 0
      fi
      LAST_ACTION="failed"
      echo -e "${RED}✗${RESET} Source version $src_ver is not newer than installed $tgt_ver (use -f to force)"
      return 1
    fi
  else
    if [[ $UPGRADE_ONLY -eq 1 ]]; then
      LAST_ACTION="skipped"
      echo -e "${YELLOW}→${RESET} $server — not installed, skipping"
      return 0
    fi
    echo -e "${GREEN}→${RESET} Installing $server ${CYAN}$src_ver${RESET}"
    do_install "$server" "$src" "$tgt" "$src_ver"
    LAST_ACTION="installed"
  fi

  # ── Post-install: venv, pip deps, config ──
  ensure_venv
  install_dependencies "$server" "$src"

  local installed_entrypoint
  installed_entrypoint="$(find_entrypoint "$tgt")"
  local venv_python
  venv_python="$(get_venv_python)"
  if [[ -n "$installed_entrypoint" ]]; then
    update_mcp_config_add "$server" "$installed_entrypoint" "$venv_python"
  fi
}

cmd_install_all() {
  ensure_dirs
  local servers
  servers="$(list_items_in_dir "$SOURCE_DIR" "mcp")"

  if [[ -z "$servers" ]]; then
    echo -e "${YELLOW}No MCP servers found in source: $SOURCE_DIR${RESET}"
    return 0
  fi

  local total=0 installed=0 skipped=0 failed=0

  while IFS= read -r server; do
    total=$((total + 1))
    if cmd_install "$server"; then
      case "$LAST_ACTION" in
        installed|upgraded) installed=$((installed + 1)) ;;
        skipped) skipped=$((skipped + 1)) ;;
        *) failed=$((failed + 1)) ;;
      esac
    else
      failed=$((failed + 1))
    fi
  done <<< "$servers"

  echo ""
  echo -e "${BOLD}Summary:${RESET} $total total, ${GREEN}$installed installed/upgraded${RESET}, ${YELLOW}$skipped skipped${RESET}"
  if [[ $failed -gt 0 ]]; then
    echo -e "${RED}$failed failed${RESET}"
  fi
}

cmd_upgrade_all() {
  ensure_dirs
  local servers
  servers="$(list_items_in_dir "$SOURCE_DIR" "mcp")"

  if [[ -z "$servers" ]]; then
    echo -e "${YELLOW}No MCP servers found in source: $SOURCE_DIR${RESET}"
    return 0
  fi

  UPGRADE_ONLY=1
  local total=0 upgraded=0 skipped=0 failed=0

  while IFS= read -r server; do
    total=$((total + 1))
    if cmd_install "$server"; then
      case "$LAST_ACTION" in
        upgraded) upgraded=$((upgraded + 1)) ;;
        skipped) skipped=$((skipped + 1)) ;;
        *) failed=$((failed + 1)) ;;
      esac
    else
      failed=$((failed + 1))
    fi
  done <<< "$servers"
  UPGRADE_ONLY=0

  echo ""
  echo -e "${BOLD}Summary:${RESET} $total total, ${GREEN}$upgraded upgraded${RESET}, ${YELLOW}$skipped skipped${RESET}"
  if [[ $failed -gt 0 ]]; then
    echo -e "${RED}$failed failed${RESET}"
    return 1
  fi
}

cmd_uninstall() {
  local server="$1"
  local tgt="$TARGET_DIR/$server"

  if [[ ! -d "$tgt" ]]; then
    echo -e "${RED}Error: MCP server '$server' is not installed${RESET}"
    exit 1
  fi

  local ver="unknown"
  local entrypoint
  entrypoint="$(find_entrypoint "$tgt")"
  if [[ -n "$entrypoint" && -f "$entrypoint" ]]; then
    ver="$(extract_version "$entrypoint")"
  fi

  # Remove from mcp-config.json before deleting the directory
  update_mcp_config_remove "$server"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "  ${BLUE}[dry-run]${RESET} Would remove $tgt"
    echo -e "${GREEN}✓${RESET} $server ${CYAN}$ver${RESET} would be uninstalled (dry-run)"
  else
    rm -rf "$tgt"
    echo -e "${GREEN}✓${RESET} $server ${CYAN}$ver${RESET} uninstalled"
  fi
}

cmd_list() {
  local servers
  servers="$(list_items_in_dir "$TARGET_DIR" "mcp")"

  if [[ -z "$servers" ]]; then
    echo -e "${YELLOW}No MCP servers installed in $TARGET_DIR${RESET}"
    return 0
  fi

  printf "${BOLD}%-30s${RESET} %s\n" "SERVER" "VERSION"
  printf '%-30s %s\n' "─────────────────────────────" "───────"

  while IFS= read -r server; do
    local ver="unknown"
    local entrypoint
    entrypoint="$(find_entrypoint "$TARGET_DIR/$server")"
    if [[ -n "$entrypoint" && -f "$entrypoint" ]]; then
      ver="$(extract_version "$entrypoint")"
    fi
    printf "%-30s ${CYAN}%s${RESET}\n" "$server" "$ver"
  done <<< "$servers"
}

cmd_list_available() {
  local servers
  servers="$(list_items_in_dir "$SOURCE_DIR" "mcp")"

  if [[ -z "$servers" ]]; then
    echo -e "${YELLOW}No MCP servers available in source: $SOURCE_DIR${RESET}"
    return 0
  fi

  printf "${BOLD}%-30s${RESET} %s\n" "SERVER" "VERSION"
  printf '%-30s %s\n' "─────────────────────────────" "───────"

  while IFS= read -r server; do
    local entrypoint
    entrypoint="$(find_entrypoint "$SOURCE_DIR/$server")"
    local ver="0.0.0"
    if [[ -n "$entrypoint" && -f "$entrypoint" ]]; then
      ver="$(extract_version "$entrypoint")"
    fi
    printf "%-30s ${CYAN}%s${RESET}\n" "$server" "$ver"
  done <<< "$servers"
}

cmd_status() {
  local available_servers
  available_servers="$(list_items_in_dir "$SOURCE_DIR" "mcp")"

  if [[ -z "$available_servers" ]]; then
    echo -e "${YELLOW}No MCP servers available in source: $SOURCE_DIR${RESET}"
    return 0
  fi

  printf "${BOLD}%-30s${RESET} %-12s %-12s %s\n" "SERVER" "INSTALLED" "AVAILABLE" "STATUS"
  printf '%-30s %-12s %-12s %s\n' "─────────────────────────────" "────────────" "────────────" "─────────────"

  while IFS= read -r server; do
    local avail_ver inst_ver status_col
    local src_entrypoint
    src_entrypoint="$(find_entrypoint "$SOURCE_DIR/$server")"
    avail_ver="0.0.0"
    if [[ -n "$src_entrypoint" && -f "$src_entrypoint" ]]; then
      avail_ver="$(extract_version "$src_entrypoint")"
    fi

    if [[ -d "$TARGET_DIR/$server" ]]; then
      local tgt_entrypoint
      tgt_entrypoint="$(find_entrypoint "$TARGET_DIR/$server")"
      inst_ver="0.0.0"
      if [[ -n "$tgt_entrypoint" && -f "$tgt_entrypoint" ]]; then
        inst_ver="$(extract_version "$tgt_entrypoint")"
      fi
      if [[ "$avail_ver" == "$inst_ver" ]]; then
        status_col="${GREEN}up-to-date${RESET}"
      elif semver_gt "$avail_ver" "$inst_ver"; then
        status_col="${YELLOW}outdated${RESET}"
      else
        status_col="${RED}source<installed${RESET}"
      fi
    else
      inst_ver="-"
      status_col="${CYAN}not-installed${RESET}"
    fi

    printf "%-30s %-12s %-12s %b\n" "$server" "$inst_ver" "$avail_ver" "$status_col"
  done <<< "$available_servers"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

parse_args "$@"

case "$COMMAND" in
  install)
    [[ -n "$ITEM_NAME" ]] || { echo -e "${RED}Error: install requires <server-name>${RESET}"; exit 1; }
    cmd_install "$ITEM_NAME"
    ;;
  install-all)
    cmd_install_all
    ;;
  upgrade)
    [[ -n "$ITEM_NAME" ]] || { echo -e "${RED}Error: upgrade requires <server-name>${RESET}"; exit 1; }
    cmd_install "$ITEM_NAME"
    ;;
  upgrade-all)
    cmd_upgrade_all
    ;;
  uninstall)
    [[ -n "$ITEM_NAME" ]] || { echo -e "${RED}Error: uninstall requires <server-name>${RESET}"; exit 1; }
    cmd_uninstall "$ITEM_NAME"
    ;;
  list)
    cmd_list
    ;;
  list-available)
    cmd_list_available
    ;;
  status)
    cmd_status
    ;;
  *)
    echo -e "${RED}Unknown command: $COMMAND${RESET}"
    usage
    exit 1
    ;;
esac
