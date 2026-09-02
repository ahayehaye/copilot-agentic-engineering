#!/usr/bin/env bash
#
# copilot-instructions-manager.sh — Install and manage the Copilot user-global
# instructions file (copilot-instructions.md)
#
# Lifecycle (deliberate deviation from the semver install/upgrade pattern):
#   install-if-missing, drift-warn (never clobber), explicit `reinstall` as
#   the only adoption path.
#
# Drift states (three-way hash comparison of target, Source, and the
# recorded state hash):
#   user-managed   target exists but no state file (no ownership assumed;
#                  takes precedence — content equality alone is not ownership)
#   up-to-date     state file present and target == Source
#   source-updated target != Source, target == recorded state (Source moved)
#   drifted        target != Source, target != recorded state (user edited)
# Drift warnings are advisory (exit 0); missing Source, unreadable target,
# or failed copy/backup exit non-zero.
#
# The Source document's SHA-256 is recorded at install time in a state
# dotfile next to the target. The instructions file itself carries no
# version marker.
#
set -euo pipefail

# ─── Source Shared Library ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/agent-manager-lib.sh"

# ─── Manager-Specific Variables ───────────────────────────────────────────────
SOURCE_DIR="${SOURCE_DIR:-${SCRIPT_DIR}/../copilot-instructions}"
# COPILOT_HOME redirects the Copilot user-level directory (one-shot test hook).
COPILOT_HOME="${COPILOT_HOME:-$HOME/.copilot}"
TARGET_DIR="$COPILOT_HOME"
TARGET_FILE="$TARGET_DIR/copilot-instructions.md"
# State dotfile in the same directory as the target; records the SHA-256 of
# the Source content at install time.
STATE_FILE="$TARGET_DIR/.copilot-instructions.sha256"
BACKUP_DIR="$TARGET_DIR/copilot-instructions.backups"

# ─── Instructions-Specific Usage ──────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: copilot-instructions-manager.sh <command> [options]

Commands:
  install         Install the instructions file if missing (never clobbers;
                  on a differing target, prints a drift warning + diff)
  status          Show installed state at a glance (up-to-date / source-updated
                  / drifted / user-managed)
  reinstall       Adopt the Source: timestamped backup of the current file,
                  replace target, refresh the state file

Options:
  --reinstall, -f               With install: alias for the reinstall command
  --dry-run, -n                 Preview changes without making them
  --source <path>               Override auto-detected copilot-instructions/ directory
  --help, -h                    Show usage

Target: ${COPILOT_HOME}/copilot-instructions.md (COPILOT_HOME defaults to ~/.copilot)
State:  ${COPILOT_HOME}/.copilot-instructions.sha256 (SHA-256 of Source at install time)
Backups: ${COPILOT_HOME}/copilot-instructions.backups/ (timestamped, sibling of target)
EOF
}

# Drift helpers (sha256_of, read_state_hash, classify_state, print_drift_diff)
# are sourced from the Shared Library (ADR-0007).

# ─── Commands ─────────────────────────────────────────────────────────────────

cmd_install() {
  local src_file="$SOURCE_DIR/copilot-instructions.md"

  if [[ ! -f "$src_file" ]]; then
    echo -e "${RED}Error: Source file not found: $src_file${RESET}"
    exit 1
  fi

  local src_hash
  src_hash="$(sha256_of "$src_file")"

  if [[ -f "$TARGET_FILE" ]]; then
    if [[ ! -r "$TARGET_FILE" ]]; then
      echo -e "${RED}Error: Target file is not readable: $TARGET_FILE${RESET}"
      exit 1
    fi
    local tgt_hash
    tgt_hash="$(sha256_of "$TARGET_FILE")"

    if [[ "$tgt_hash" == "$src_hash" ]]; then
      LAST_ACTION="skipped"
      echo -e "${GREEN}✓${RESET} copilot-instructions.md ${CYAN}${src_hash:0:12}${RESET} — already installed, skipping"
      return 0
    fi

    # Existing target differs from the Source. Never clobber: warn with a
    # unified diff and leave the file untouched (advisory, exit 0).
    local state
    state="$(classify_state "$src_hash" "$tgt_hash" "$STATE_FILE")"
    LAST_ACTION="skipped"
    case "$state" in
      user-managed)
        echo -e "${YELLOW}⚠${RESET} copilot-instructions.md exists but has no manager state (user-managed) — not clobbering"
        ;;
      source-updated)
        echo -e "${YELLOW}⚠${RESET} copilot-instructions.md differs from the Source (Source changed since install) — not clobbering"
        ;;
      drifted)
        echo -e "${YELLOW}⚠${RESET} copilot-instructions.md differs from the Source (file edited after install) — not clobbering"
        ;;
    esac
    echo -e "  ${YELLOW}Unified diff (target vs Source):${RESET}"
    print_drift_diff "$TARGET_FILE" "$src_file"
    echo -e "  Run ${CYAN}reinstall${RESET} to adopt the Source (a timestamped backup will be kept)."
    return 0
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "  ${BLUE}[dry-run]${RESET} Would copy $src_file → $TARGET_FILE"
    echo -e "  ${BLUE}[dry-run]${RESET} Would record SHA-256 ${CYAN}${src_hash:0:12}${RESET} in $STATE_FILE"
    echo -e "${GREEN}✓${RESET} copilot-instructions.md would be installed (dry-run)"
    LAST_ACTION="installed"
    return 0
  fi

  ensure_dirs
  cp "$src_file" "$TARGET_FILE" || {
    echo -e "${RED}Error: Failed to copy $src_file → $TARGET_FILE${RESET}"
    exit 1
  }
  echo "$src_hash" > "$STATE_FILE"
  echo -e "${GREEN}✓${RESET} copilot-instructions.md ${CYAN}${src_hash:0:12}${RESET} installed → $TARGET_FILE"
  LAST_ACTION="installed"
}

cmd_status() {
  local src_file="$SOURCE_DIR/copilot-instructions.md"
  local src_hash=""

  if [[ -f "$src_file" ]]; then
    src_hash="$(sha256_of "$src_file")"
  fi

  echo -e "${BOLD}copilot-instructions-manager status:${RESET}"
  echo -e "  ${BOLD}Target:${RESET} $TARGET_FILE"
  echo -e "  ${BOLD}State file:${RESET} $STATE_FILE"
  echo ""

  if [[ ! -f "$TARGET_FILE" ]]; then
    echo -e "  ${BOLD}copilot-instructions.md:${RESET} ${CYAN}not-installed${RESET}"
    return 0
  fi

  if [[ -z "$src_hash" ]]; then
    echo -e "  ${YELLOW}⚠ Source file not found: $src_file${RESET}"
    exit 1
  fi

  local tgt_hash
  tgt_hash="$(sha256_of "$TARGET_FILE")"

  local state
  state="$(classify_state "$src_hash" "$tgt_hash" "$STATE_FILE")"
  case "$state" in
    up-to-date)
      echo -e "  ${BOLD}copilot-instructions.md:${RESET} ${GREEN}up-to-date${RESET} (${CYAN}${tgt_hash:0:12}${RESET})"
      ;;
    user-managed)
      echo -e "  ${BOLD}copilot-instructions.md:${RESET} ${YELLOW}user-managed${RESET} (${CYAN}${tgt_hash:0:12}${RESET}) — no state file, no ownership assumed"
      print_drift_diff "$TARGET_FILE" "$src_file"
      ;;
    source-updated)
      echo -e "  ${BOLD}copilot-instructions.md:${RESET} ${YELLOW}source-updated${RESET} (${CYAN}${tgt_hash:0:12}${RESET}) — Source changed since install; run reinstall to adopt"
      print_drift_diff "$TARGET_FILE" "$src_file"
      ;;
    drifted)
      echo -e "  ${BOLD}copilot-instructions.md:${RESET} ${YELLOW}drifted${RESET} (${CYAN}${tgt_hash:0:12}${RESET}) — file edited after install; run reinstall to adopt"
      print_drift_diff "$TARGET_FILE" "$src_file"
      ;;
  esac
}

# ─── Reinstall (the only adoption path) ──────────────────────────────────────

cmd_reinstall() {
  local src_file="$SOURCE_DIR/copilot-instructions.md"

  if [[ ! -f "$src_file" ]]; then
    echo -e "${RED}Error: Source file not found: $src_file${RESET}"
    exit 1
  fi

  local src_hash
  src_hash="$(sha256_of "$src_file")"

  if [[ ! -f "$TARGET_FILE" ]]; then
    echo -e "Target missing — nothing to back up; installing fresh."
    cmd_install
    return 0
  fi

  if [[ ! -r "$TARGET_FILE" ]]; then
    echo -e "${RED}Error: Target file is not readable: $TARGET_FILE${RESET}"
    exit 1
  fi

  if [[ ! -w "$TARGET_DIR" ]]; then
    echo -e "${RED}Error: Target directory is not writable (cannot create backup): $TARGET_DIR${RESET}"
    exit 1
  fi

  local ts backup_path
  ts="$(date +%Y%m%d-%H%M%S)"
  backup_path="$BACKUP_DIR/copilot-instructions-${ts}.md"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "  ${BLUE}[dry-run]${RESET} Would backup $TARGET_FILE → $backup_path"
    echo -e "  ${BLUE}[dry-run]${RESET} Would copy $src_file → $TARGET_FILE"
    echo -e "  ${BLUE}[dry-run]${RESET} Would record SHA-256 ${CYAN}${src_hash:0:12}${RESET} in $STATE_FILE"
    echo -e "${GREEN}✓${RESET} copilot-instructions.md would be reinstalled (dry-run)"
    LAST_ACTION="reinstalled"
    return 0
  fi

  ensure_dirs
  cp "$TARGET_FILE" "$backup_path" || {
    echo -e "${RED}Error: Failed to backup $TARGET_FILE → $backup_path${RESET}"
    exit 1
  }
  cp "$src_file" "$TARGET_FILE" || {
    echo -e "${RED}Error: Failed to copy $src_file → $TARGET_FILE, restoring from backup${RESET}"
    cp "$backup_path" "$TARGET_FILE"
    exit 1
  }
  echo "$src_hash" > "$STATE_FILE" || {
    echo -e "${RED}Error: Failed to write state file: $STATE_FILE${RESET}"
    exit 1
  }
  echo -e "${GREEN}✓${RESET} copilot-instructions.md ${CYAN}${src_hash:0:12}${RESET} reinstalled → $TARGET_FILE (backup: ${backup_path})"
  LAST_ACTION="reinstalled"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

parse_args "$@"

case "$COMMAND" in
  install)
    if [[ $FORCE -eq 1 ]]; then
      cmd_reinstall
    else
      cmd_install
    fi
    ;;
  reinstall)
    cmd_reinstall
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
