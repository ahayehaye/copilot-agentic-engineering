#!/usr/bin/env bash
#
# skill-manager.sh — Install, upgrade, and uninstall agent skills
#
set -euo pipefail

# ─── Source Shared Library ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/agent-manager-lib.sh"

# ─── Manager-Specific Variables ───────────────────────────────────────────────
SOURCE_DIR="${SCRIPT_DIR}/../skills"
TARGET_DIR="$HOME/.agents/skills"
BACKUP_DIR="$HOME/.agents/skills.backups"

# ─── Skill-Specific Usage ─────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage: skill-manager.sh <command> [options] [args]

Commands:
  install <skill-name>          Install or upgrade a single skill
  install-all                   Install all skills from source
  upgrade <skill-name>          Alias for install <skill-name>
  upgrade-all                   Upgrade installed skills with newer source versions
  uninstall <skill-name>        Remove an installed skill
  list                          Show installed skills with versions
  list-available                Show skills available in source
  status                        Compare installed vs available (outdated/new)

Options:
  --reinstall, -f               Force reinstall even if version matches
  --dry-run, -n                 Preview changes without making them
  --source <path>               Override auto-detected skills/ directory
  --help, -h                    Show usage
EOF
}

# ─── Commands ─────────────────────────────────────────────────────────────────

cmd_install() {
  local skill="$1"
  local src="$SOURCE_DIR/$skill"
  local tgt="$TARGET_DIR/$skill"

  if [[ ! -f "$src/SKILL.md" ]]; then
    echo -e "${RED}Error: Skill '$skill' not found in source: $src${RESET}"
    exit 1
  fi

  local src_ver
  src_ver="$(extract_version "$src/SKILL.md")"

  if [[ -d "$tgt" && -f "$tgt/SKILL.md" ]]; then
    local tgt_ver
    tgt_ver="$(extract_version "$tgt/SKILL.md")"

    if [[ "$src_ver" == "$tgt_ver" && $FORCE -eq 0 ]]; then
      LAST_ACTION="skipped"
      echo -e "${GREEN}✓${RESET} $skill ${CYAN}$tgt_ver${RESET} — already up to date, skipping"
      return 0
    fi

    if semver_gt "$src_ver" "$tgt_ver"; then
      echo -e "${YELLOW}→${RESET} Upgrading $skill ${CYAN}$tgt_ver${RESET} → ${CYAN}$src_ver${RESET}"
      do_upgrade "$skill" "$src" "$tgt" "$src_ver" "$tgt_ver"
      LAST_ACTION="upgraded"
    elif [[ $FORCE -eq 1 && ( $UPGRADE_ONLY -eq 0 || "$src_ver" == "$tgt_ver" ) ]]; then
      echo -e "${YELLOW}→${RESET} Force reinstalling $skill ${CYAN}$tgt_ver${RESET} → ${CYAN}$src_ver${RESET}"
      do_upgrade "$skill" "$src" "$tgt" "$src_ver" "$tgt_ver"
      LAST_ACTION="upgraded"
    else
      if [[ $UPGRADE_ONLY -eq 1 ]]; then
        LAST_ACTION="skipped"
        echo -e "${YELLOW}⚠${RESET} WARNING: $skill source ${CYAN}$src_ver${RESET} is older than installed ${CYAN}$tgt_ver${RESET} — skipping"
        return 0
      fi
      LAST_ACTION="failed"
      echo -e "${RED}✗${RESET} Source version $src_ver is not newer than installed $tgt_ver (use -f to force)"
      return 1
    fi
  else
    if [[ $UPGRADE_ONLY -eq 1 ]]; then
      LAST_ACTION="skipped"
      echo -e "${YELLOW}→${RESET} $skill — not installed, skipping"
      return 0
    fi
    echo -e "${GREEN}→${RESET} Installing $skill ${CYAN}$src_ver${RESET}"
    do_install "$skill" "$src" "$tgt" "$src_ver"
    LAST_ACTION="installed"
  fi
}

cmd_install_all() {
  ensure_dirs
  local skills
  skills="$(list_items_in_dir "$SOURCE_DIR" "skill")"

  if [[ -z "$skills" ]]; then
    echo -e "${YELLOW}No skills found in source: $SOURCE_DIR${RESET}"
    return 0
  fi

  local total=0 installed=0 skipped=0 failed=0

  while IFS= read -r skill; do
    total=$((total + 1))
    if cmd_install "$skill"; then
      case "$LAST_ACTION" in
        installed|upgraded) installed=$((installed + 1)) ;;
        skipped) skipped=$((skipped + 1)) ;;
        *) failed=$((failed + 1)) ;;
      esac
    else
      failed=$((failed + 1))
    fi
  done <<< "$skills"

  echo ""
  echo -e "${BOLD}Summary:${RESET} $total total, ${GREEN}$installed installed/upgraded${RESET}, ${YELLOW}$skipped skipped${RESET}"
  if [[ $failed -gt 0 ]]; then
    echo -e "${RED}$failed failed${RESET}"
  fi
}

cmd_upgrade_all() {
  ensure_dirs
  local skills
  skills="$(list_items_in_dir "$SOURCE_DIR" "skill")"

  if [[ -z "$skills" ]]; then
    echo -e "${YELLOW}No skills found in source: $SOURCE_DIR${RESET}"
    return 0
  fi

  UPGRADE_ONLY=1
  local total=0 upgraded=0 skipped=0 failed=0

  while IFS= read -r skill; do
    total=$((total + 1))
    if cmd_install "$skill"; then
      case "$LAST_ACTION" in
        upgraded) upgraded=$((upgraded + 1)) ;;
        skipped) skipped=$((skipped + 1)) ;;
        *) failed=$((failed + 1)) ;;
      esac
    else
      failed=$((failed + 1))
    fi
  done <<< "$skills"
  UPGRADE_ONLY=0

  echo ""
  echo -e "${BOLD}Summary:${RESET} $total total, ${GREEN}$upgraded upgraded${RESET}, ${YELLOW}$skipped skipped${RESET}"
  if [[ $failed -gt 0 ]]; then
    echo -e "${RED}$failed failed${RESET}"
    return 1
  fi
}

cmd_uninstall() {
  local skill="$1"
  local tgt="$TARGET_DIR/$skill"

  if [[ ! -d "$tgt" ]]; then
    echo -e "${RED}Error: Skill '$skill' is not installed${RESET}"
    exit 1
  fi

  local ver="unknown"
  if [[ -f "$tgt/SKILL.md" ]]; then
    ver="$(extract_version "$tgt/SKILL.md")"
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "  ${BLUE}[dry-run]${RESET} Would remove $tgt"
    echo -e "${GREEN}✓${RESET} $skill ${CYAN}$ver${RESET} would be uninstalled (dry-run)"
  else
    rm -rf "$tgt"
    echo -e "${GREEN}✓${RESET} $skill ${CYAN}$ver${RESET} uninstalled"
  fi
}

cmd_list() {
  local skills
  skills="$(list_items_in_dir "$TARGET_DIR" "skill")"

  if [[ -z "$skills" ]]; then
    echo -e "${YELLOW}No skills installed in $TARGET_DIR${RESET}"
    return 0
  fi

  printf "${BOLD}%-30s${RESET} %s\n" "SKILL" "VERSION"
  printf '%-30s %s\n' "─────────────────────────────" "───────"

  while IFS= read -r skill; do
    local ver
    ver="$(extract_version "$TARGET_DIR/$skill/SKILL.md")"
    printf "%-30s ${CYAN}%s${RESET}\n" "$skill" "$ver"
  done <<< "$skills"
}

cmd_list_available() {
  local skills
  skills="$(list_items_in_dir "$SOURCE_DIR" "skill")"

  if [[ -z "$skills" ]]; then
    echo -e "${YELLOW}No skills available in source: $SOURCE_DIR${RESET}"
    return 0
  fi

  printf "${BOLD}%-30s${RESET} %s\n" "SKILL" "VERSION"
  printf '%-30s %s\n' "─────────────────────────────" "───────"

  while IFS= read -r skill; do
    local ver
    ver="$(extract_version "$SOURCE_DIR/$skill/SKILL.md")"
    printf "%-30s ${CYAN}%s${RESET}\n" "$skill" "$ver"
  done <<< "$skills"
}

cmd_status() {
  local available_skills
  available_skills="$(list_items_in_dir "$SOURCE_DIR" "skill")"

  if [[ -z "$available_skills" ]]; then
    echo -e "${YELLOW}No skills available in source: $SOURCE_DIR${RESET}"
    return 0
  fi

  printf "${BOLD}%-30s${RESET} %-12s %-12s %s\n" "SKILL" "INSTALLED" "AVAILABLE" "STATUS"
  printf '%-30s %-12s %-12s %s\n' "─────────────────────────────" "────────────" "────────────" "─────────────"

  while IFS= read -r skill; do
    local avail_ver inst_ver status_col
    avail_ver="$(extract_version "$SOURCE_DIR/$skill/SKILL.md")"

    if [[ -d "$TARGET_DIR/$skill" && -f "$TARGET_DIR/$skill/SKILL.md" ]]; then
      inst_ver="$(extract_version "$TARGET_DIR/$skill/SKILL.md")"
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

    printf "%-30s %-12s %-12s %b\n" "$skill" "$inst_ver" "$avail_ver" "$status_col"
  done <<< "$available_skills"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

parse_args "$@"

case "$COMMAND" in
  install)
    [[ -n "$ITEM_NAME" ]] || { echo -e "${RED}Error: install requires <skill-name>${RESET}"; exit 1; }
    cmd_install "$ITEM_NAME"
    ;;
  install-all)
    cmd_install_all
    ;;
  upgrade)
    [[ -n "$ITEM_NAME" ]] || { echo -e "${RED}Error: upgrade requires <skill-name>${RESET}"; exit 1; }
    cmd_install "$ITEM_NAME"
    ;;
  upgrade-all)
    cmd_upgrade_all
    ;;
  uninstall)
    [[ -n "$ITEM_NAME" ]] || { echo -e "${RED}Error: uninstall requires <skill-name>${RESET}"; exit 1; }
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
