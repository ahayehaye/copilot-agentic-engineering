#!/usr/bin/env bash
#
# copilot-agent-manager.sh — Install, upgrade, and uninstall Copilot custom agents
#
set -euo pipefail

# ─── Source Shared Library ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/agent-manager-lib.sh"

# ─── Manager-Specific Variables ───────────────────────────────────────────────
SOURCE_DIR="${SOURCE_DIR:-${SCRIPT_DIR}/../copilot-agents}"
TARGET_DIR="$HOME/.copilot/agents"
BACKUP_DIR="$HOME/.copilot/agents.backups"

# ─── Agent-Specific Usage ─────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage: copilot-agent-manager.sh <command> [options] [args]

Commands:
  install <agent-name>          Install or upgrade a single agent
  install-all                   Install all agents from source
  upgrade <agent-name>          Alias for install <agent-name>
  upgrade-all                   Upgrade installed agents with newer source versions
  uninstall <agent-name>        Remove an installed agent
  list                          Show installed agents with versions
  list-available                Show agents available in source
  status                        Compare installed vs available (outdated/new)

Options:
  --reinstall, -f               Force reinstall even if version matches
  --dry-run, -n                 Preview changes without making them
  --source <path>               Override auto-detected copilot-agents/ directory
  --help, -h                    Show usage
EOF
}

# ─── Agent Discovery ──────────────────────────────────────────────────────────
# Find agents by locating *.agent.md files in subdirectories of the given dir.
# Outputs one agent name (directory name) per line.
discover_agents_in_dir() {
  local dir="$1"

  if [[ ! -d "$dir" ]]; then
    return
  fi

  for d in "$dir"/*/; do
    [[ -d "$d" ]] || continue
    # Check if this subdirectory contains a *.agent.md file
    if compgen -G "$d"*.agent.md > /dev/null 2>&1; then
      basename "$d"
    fi
  done
}

# Find the .agent.md file for a given agent name in a directory.
find_agent_file() {
  local dir="$1"
  local name="$2"

  if [[ -d "$dir/$name" ]]; then
    local agent_file
    agent_file="$(find "$dir/$name" -maxdepth 1 -name '*.agent.md' -print -quit 2>/dev/null)"
    if [[ -n "$agent_file" ]]; then
      echo "$agent_file"
    fi
  fi
}

# ─── Commands ─────────────────────────────────────────────────────────────────

cmd_install() {
  local agent="$1"
  local src_dir="$SOURCE_DIR/$agent"
  local tgt_file="$TARGET_DIR/${agent}.agent.md"

  local src_file
  src_file="$(find_agent_file "$SOURCE_DIR" "$agent")"

  if [[ -z "$src_file" ]]; then
    echo -e "${RED}Error: Agent '$agent' not found in source: $src_dir${RESET}"
    exit 1
  fi

  local src_ver
  src_ver="$(extract_version "$src_file")"

  if [[ -f "$tgt_file" ]]; then
    local tgt_ver
    tgt_ver="$(extract_version "$tgt_file")"

    if [[ "$src_ver" == "$tgt_ver" && $FORCE -eq 0 ]]; then
      LAST_ACTION="skipped"
      echo -e "${GREEN}✓${RESET} $agent ${CYAN}$tgt_ver${RESET} — already up to date, skipping"
      return 0
    fi

    if semver_gt "$src_ver" "$tgt_ver"; then
      echo -e "${YELLOW}→${RESET} Upgrading $agent ${CYAN}$tgt_ver${RESET} → ${CYAN}$src_ver${RESET}"
      do_upgrade "$agent" "$src_file" "$tgt_file" "$src_ver" "$tgt_ver"
      LAST_ACTION="upgraded"
    elif [[ $FORCE -eq 1 && ( $UPGRADE_ONLY -eq 0 || "$src_ver" == "$tgt_ver" ) ]]; then
      echo -e "${YELLOW}→${RESET} Force reinstalling $agent ${CYAN}$tgt_ver${RESET} → ${CYAN}$src_ver${RESET}"
      do_upgrade "$agent" "$src_file" "$tgt_file" "$src_ver" "$tgt_ver"
      LAST_ACTION="upgraded"
    else
      if [[ $UPGRADE_ONLY -eq 1 ]]; then
        LAST_ACTION="skipped"
        echo -e "${YELLOW}⚠${RESET} WARNING: $agent source ${CYAN}$src_ver${RESET} is older than installed ${CYAN}$tgt_ver${RESET} — skipping"
        return 0
      fi
      LAST_ACTION="failed"
      echo -e "${RED}✗${RESET} Source version $src_ver is not newer than installed $tgt_ver (use -f to force)"
      return 1
    fi
  else
    if [[ $UPGRADE_ONLY -eq 1 ]]; then
      LAST_ACTION="skipped"
      echo -e "${YELLOW}→${RESET} $agent — not installed, skipping"
      return 0
    fi
    echo -e "${GREEN}→${RESET} Installing $agent ${CYAN}$src_ver${RESET}"
    do_install "$agent" "$src_file" "$tgt_file" "$src_ver"
    LAST_ACTION="installed"
  fi
}

cmd_install_all() {
  ensure_dirs
  local agents
  agents="$(discover_agents_in_dir "$SOURCE_DIR")"

  if [[ -z "$agents" ]]; then
    echo -e "${YELLOW}No agents found in source: $SOURCE_DIR${RESET}"
    return 0
  fi

  local total=0 installed=0 skipped=0 failed=0

  while IFS= read -r agent; do
    total=$((total + 1))
    if cmd_install "$agent"; then
      case "$LAST_ACTION" in
        installed|upgraded) installed=$((installed + 1)) ;;
        skipped) skipped=$((skipped + 1)) ;;
        *) failed=$((failed + 1)) ;;
      esac
    else
      failed=$((failed + 1))
    fi
  done <<< "$agents"

  echo ""
  echo -e "${BOLD}Summary:${RESET} $total total, ${GREEN}$installed installed/upgraded${RESET}, ${YELLOW}$skipped skipped${RESET}"
  if [[ $failed -gt 0 ]]; then
    echo -e "${RED}$failed failed${RESET}"
  fi
}

cmd_upgrade_all() {
  ensure_dirs
  local agents
  agents="$(discover_agents_in_dir "$SOURCE_DIR")"

  if [[ -z "$agents" ]]; then
    echo -e "${YELLOW}No agents found in source: $SOURCE_DIR${RESET}"
    return 0
  fi

  UPGRADE_ONLY=1
  local total=0 upgraded=0 skipped=0 failed=0

  while IFS= read -r agent; do
    total=$((total + 1))
    if cmd_install "$agent"; then
      case "$LAST_ACTION" in
        upgraded) upgraded=$((upgraded + 1)) ;;
        skipped) skipped=$((skipped + 1)) ;;
        *) failed=$((failed + 1)) ;;
      esac
    else
      failed=$((failed + 1))
    fi
  done <<< "$agents"
  UPGRADE_ONLY=0

  echo ""
  echo -e "${BOLD}Summary:${RESET} $total total, ${GREEN}$upgraded upgraded${RESET}, ${YELLOW}$skipped skipped${RESET}"
  if [[ $failed -gt 0 ]]; then
    echo -e "${RED}$failed failed${RESET}"
    return 1
  fi
}

cmd_uninstall() {
  local agent="$1"
  local tgt_file="$TARGET_DIR/${agent}.agent.md"

  if [[ ! -f "$tgt_file" ]]; then
    echo -e "${RED}Error: Agent '$agent' is not installed${RESET}"
    exit 1
  fi

  local ver="unknown"
  ver="$(extract_version "$tgt_file")"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "  ${BLUE}[dry-run]${RESET} Would remove $tgt_file"
    echo -e "${GREEN}✓${RESET} $agent ${CYAN}$ver${RESET} would be uninstalled (dry-run)"
  else
    rm -f "$tgt_file"
    echo -e "${GREEN}✓${RESET} $agent ${CYAN}$ver${RESET} uninstalled"
  fi
}

cmd_list() {
  local agents=""

  if [[ ! -d "$TARGET_DIR" ]]; then
    echo -e "${YELLOW}No agents installed in $TARGET_DIR${RESET}"
    return 0
  fi

  for f in "$TARGET_DIR"/*.agent.md; do
    [[ -f "$f" ]] || continue
    local name
    name="$(basename "$f" .agent.md)"
    if [[ -n "$agents" ]]; then
      agents="$agents"$'\n'"$name"
    else
      agents="$name"
    fi
  done

  if [[ -z "$agents" ]]; then
    echo -e "${YELLOW}No agents installed in $TARGET_DIR${RESET}"
    return 0
  fi

  printf "${BOLD}%-30s${RESET} %s\n" "AGENT" "VERSION"
  printf '%-30s %s\n' "─────────────────────────────" "───────"

  while IFS= read -r agent; do
    local ver
    ver="$(extract_version "$TARGET_DIR/${agent}.agent.md")"
    printf "%-30s ${CYAN}%s${RESET}\n" "$agent" "$ver"
  done <<< "$agents"
}

cmd_list_available() {
  local agents
  agents="$(discover_agents_in_dir "$SOURCE_DIR")"

  if [[ -z "$agents" ]]; then
    echo -e "${YELLOW}No agents available in source: $SOURCE_DIR${RESET}"
    return 0
  fi

  printf "${BOLD}%-30s${RESET} %s\n" "AGENT" "VERSION"
  printf '%-30s %s\n' "─────────────────────────────" "───────"

  while IFS= read -r agent; do
    local ver
    local agent_file
    agent_file="$(find_agent_file "$SOURCE_DIR" "$agent")"
    ver="$(extract_version "$agent_file")"
    printf "%-30s ${CYAN}%s${RESET}\n" "$agent" "$ver"
  done <<< "$agents"
}

cmd_status() {
  local available_agents
  available_agents="$(discover_agents_in_dir "$SOURCE_DIR")"

  if [[ -z "$available_agents" ]]; then
    echo -e "${YELLOW}No agents available in source: $SOURCE_DIR${RESET}"
    return 0
  fi

  printf "${BOLD}%-30s${RESET} %-12s %-12s %s\n" "AGENT" "INSTALLED" "AVAILABLE" "STATUS"
  printf '%-30s %-12s %-12s %s\n' "─────────────────────────────" "────────────" "────────────" "─────────────"

  while IFS= read -r agent; do
    local avail_ver inst_ver status_col
    local agent_file
    agent_file="$(find_agent_file "$SOURCE_DIR" "$agent")"
    avail_ver="$(extract_version "$agent_file")"

    if [[ -f "$TARGET_DIR/${agent}.agent.md" ]]; then
      inst_ver="$(extract_version "$TARGET_DIR/${agent}.agent.md")"
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

    printf "%-30s %-12s %-12s %b\n" "$agent" "$inst_ver" "$avail_ver" "$status_col"
  done <<< "$available_agents"
}

# ─── Agent-specific install/upgrade (flat file, not directory copy) ───────────

do_install() {
  local item="$1" src="$2" tgt="$3" ver="$4"
  ensure_dirs
  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "  ${BLUE}[dry-run]${RESET} Would copy $src → $tgt"
    echo -e "${GREEN}✓${RESET} $item ${CYAN}$ver${RESET} installed (dry-run)"
  else
    cp "$src" "$tgt"
    echo -e "${GREEN}✓${RESET} $item ${CYAN}$ver${RESET} installed"
  fi
}

do_upgrade() {
  local item="$1" src="$2" tgt="$3" src_ver="$4" tgt_ver="$5"
  ensure_dirs
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local backup_path="$BACKUP_DIR/${item}.agent.md-${ts}"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "  ${BLUE}[dry-run]${RESET} Would backup $tgt → $backup_path"
    echo -e "  ${BLUE}[dry-run]${RESET} Would copy $src → $tgt"
    echo -e "${GREEN}✓${RESET} $item ${CYAN}$tgt_ver${RESET} → ${CYAN}$src_ver${RESET} upgraded (dry-run)"
  else
    cp "$tgt" "$backup_path"
    cp "$src" "$tgt" || {
      echo -e "${RED}Error: Upgrade failed, restoring from backup${RESET}"
      cp "$backup_path" "$tgt"
      exit 1
    }
    echo -e "${GREEN}✓${RESET} $item ${CYAN}$tgt_ver${RESET} → ${CYAN}$src_ver${RESET} upgraded (backup: ${backup_path})"
  fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

parse_args "$@"

case "$COMMAND" in
  install)
    [[ -n "$ITEM_NAME" ]] || { echo -e "${RED}Error: install requires <agent-name>${RESET}"; exit 1; }
    cmd_install "$ITEM_NAME"
    ;;
  install-all)
    cmd_install_all
    ;;
  upgrade)
    [[ -n "$ITEM_NAME" ]] || { echo -e "${RED}Error: upgrade requires <agent-name>${RESET}"; exit 1; }
    cmd_install "$ITEM_NAME"
    ;;
  upgrade-all)
    cmd_upgrade_all
    ;;
  uninstall)
    [[ -n "$ITEM_NAME" ]] || { echo -e "${RED}Error: uninstall requires <agent-name>${RESET}"; exit 1; }
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
