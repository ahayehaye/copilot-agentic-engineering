#!/usr/bin/env bash
#
# agent-manager-lib.sh — Shared library for agent item managers (skills, MCP servers, …)
#
# Source this file from thin wrapper scripts. Do NOT execute directly.
#

# ─── Idempotency guard ────────────────────────────────────────────────────────
if [[ -n "${LIB_LOADED:-}" ]]; then
  return 0 2>/dev/null || true
fi
LIB_LOADED=1

# ─── Colours (disabled when not a terminal) ───────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; RESET=''
fi

# ─── Global variables ─────────────────────────────────────────────────────────
COMMAND=""
ITEM_NAME=""
FORCE=0
DRY_RUN=0
LAST_ACTION=""
# Internal flag: set to 1 by a manager's upgrade-all path for the duration of
# its bulk loop. Single-item install skips not-installed and source-older
# items instead of installing/failing. Never exposed as a CLI option.
UPGRADE_ONLY=0
SOURCE_DIR=""
TARGET_DIR=""
# Set explicitly by each wrapper manager (see ADR-0003); there is no fallback.
BACKUP_DIR=""

# ─── CLI Parsing ──────────────────────────────────────────────────────────────

# Generic usage — override in wrapper if needed.
usage() {
  cat <<'EOF'
Usage: <manager>.sh <command> [options] [args]

Options:
  --reinstall, -f               Force reinstall even if version matches
  --dry-run, -n                 Preview changes without making them
  --source <path>               Override auto-detected source directory
  --help, -h                    Show usage
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reinstall|-f) FORCE=1; shift ;;
      --dry-run|-n)    DRY_RUN=1; shift ;;
      --source)        SOURCE_DIR="$2"; shift 2 ;;
      --help|-h)       usage; exit 0 ;;
      -*)              echo -e "${RED}Unknown option: $1${RESET}"; usage; exit 1 ;;
      *)
        if [[ -z "$COMMAND" ]]; then
          COMMAND="$1"
        elif [[ -z "$ITEM_NAME" ]]; then
          ITEM_NAME="$1"
        else
          echo -e "${RED}Unexpected argument: $1${RESET}"; usage; exit 1
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$COMMAND" ]]; then
    echo -e "${RED}Error: No command specified.${RESET}"
    usage
    exit 1
  fi
}

# ─── Version Helpers ──────────────────────────────────────────────────────────

# Extract version from a file. Supports three formats:
#   1. YAML frontmatter (SKILL.md / MCP.md):  version: X.Y.Z  between --- markers
#   2. Python header comment:                  # version: X.Y.Z
#   3. TypeScript header comment:              // version: X.Y.Z
extract_version() {
  local file="$1"
  local version=""

  if [[ ! -f "$file" ]]; then
    echo "0.0.0"
    return
  fi

  # Try YAML frontmatter first (works for .md files with --- delimiters)
  local in_frontmatter=0
  while IFS= read -r line; do
    line="${line%$'\r'}"  # Strip trailing CR for CRLF files
    if [[ "$line" == "---" ]]; then
      if [[ $in_frontmatter -eq 0 ]]; then
        in_frontmatter=1
        continue
      else
        break
      fi
    fi
    if [[ $in_frontmatter -eq 1 ]]; then
      if [[ "$line" =~ ^version:[[:space:]]*(.*) ]]; then
        version="${BASH_REMATCH[1]}"
        version="$(echo "$version" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        if [[ -n "$version" ]]; then
          echo "$version"
          return
        fi
      fi
    fi
  done < "$file"

  # Fall back to Python-style header comment:  # version: X.Y.Z
  if [[ -z "$version" ]]; then
    version="$(grep -m1 '^# version:' "$file" 2>/dev/null | sed 's/\r$//' | sed 's/^# version:[[:space:]]*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  fi

  # Fall back to TypeScript-style header comment:  // version: X.Y.Z
  if [[ -z "$version" ]]; then
    version="$(grep -m1 '^// version:' "$file" 2>/dev/null | sed 's/\r$//' | sed 's|^// version:[[:space:]]*||' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  fi

  echo "${version:-0.0.0}"
}

# Return 0 if semver $1 > $2, 1 otherwise.
semver_gt() {
  local a="$1" b="$2"

  if [[ "$a" == "$b" ]]; then
    return 1
  fi

  local a_major a_minor a_patch b_major b_minor b_patch
  IFS='.' read -r a_major a_minor a_patch <<< "$a"
  IFS='.' read -r b_major b_minor b_patch <<< "$b"

  a_major="${a_major:-0}"; a_minor="${a_minor:-0}"; a_patch="${a_patch:-0}"
  b_major="${b_major:-0}"; b_minor="${b_minor:-0}"; b_patch="${b_patch:-0}"

  if ! [[ "$a_major" =~ ^[0-9]+$ && "$b_major" =~ ^[0-9]+$ ]]; then
    if [[ "$a" > "$b" ]]; then return 0; else return 1; fi
  fi

  if (( a_major > b_major )); then return 0; fi
  if (( a_major < b_major )); then return 1; fi
  if (( a_minor > b_minor )); then return 0; fi
  if (( a_minor < b_minor )); then return 1; fi
  if (( a_patch > b_patch )); then return 0; fi
  return 1
}

# ─── Drift Helpers (ADR-0007) ─────────────────────────────────────────────────
# Content-hash versioning and drift classification for versionless files (e.g.
# copilot-instructions.md, pi keybindings). The Source's SHA-256 is recorded
# in a state dotfile at install time; drift is a three-way hash comparison of
# Target, Source, and the recorded state. Drift is advisory: a differing
# target is never clobbered, and `reinstall` is the only adoption path.

# SHA-256 of a file's content (hex digest).
#   $1 — file path
sha256_of() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  else
    shasum -a 256 "$file" | awk '{print $1}'
  fi
}

# Read the recorded SHA-256 from a state file (empty when absent/empty).
#   $1 — state file path
read_state_hash() {
  local state_file="$1"
  if [[ -f "$state_file" ]]; then
    cat "$state_file" 2>/dev/null | tr -d '[:space:]'
  fi
}

# Classify a target's state via three-way hash comparison.
# Prints one of: up-to-date | source-updated | drifted | user-managed
#   $1 — Source hash (may be empty when the Source is missing)
#   $2 — target hash
#   $3 — state file path (records the Source hash at install time)
classify_state() {
  local src_hash="$1" tgt_hash="$2" state_file="$3"
  if [[ ! -f "$state_file" ]]; then
    echo "user-managed"
  elif [[ -n "$src_hash" && "$tgt_hash" == "$src_hash" ]]; then
    echo "up-to-date"
  elif [[ "$tgt_hash" == "$(read_state_hash "$state_file")" ]]; then
    echo "source-updated"
  else
    echo "drifted"
  fi
}

# Print the unified diff between a target file and the Source, indented.
#   $1 — target file path
#   $2 — Source file path
print_drift_diff() {
  local target_file="$1"
  local src_file="$2"
  diff -u "$target_file" "$src_file" | sed 's/^/  /' || true
}

# ─── Discovery ────────────────────────────────────────────────────────────────

# List items (skills or MCP servers) in a directory.
#   $1 — directory path
#   $2 — type: "skill" (checks for SKILL.md) or "mcp" (checks for requirements.txt + .py)
list_items_in_dir() {
  local dir="$1"
  local type="${2:-skill}"

  if [[ ! -d "$dir" ]]; then
    return
  fi

  for d in "$dir"/*/; do
    [[ -d "$d" ]] || continue
    local name
    name="$(basename "$d")"

    case "$type" in
      skill)
        [[ -f "$d/SKILL.md" ]] && echo "$name"
        ;;
      mcp)
        # MCP server: must have both requirements.txt and at least one .py file
        if [[ -f "$d/requirements.txt" ]] && compgen -G "$d/*.py" > /dev/null 2>&1; then
          echo "$name"
        fi
        ;;
    esac
  done
}

# ─── Directory setup ──────────────────────────────────────────────────────────

ensure_dirs() {
  if [[ -z "$BACKUP_DIR" ]]; then
    echo -e "${RED}Error: BACKUP_DIR is not set. Each wrapper manager must define it (see ADR-0003).${RESET}"
    exit 1
  fi
  if [[ $DRY_RUN -eq 0 ]]; then
    mkdir -p "$TARGET_DIR"
    mkdir -p "$BACKUP_DIR"
  fi
}

# ─── Install ──────────────────────────────────────────────────────────────────

do_install() {
  local item="$1" src="$2" tgt="$3" ver="$4"
  ensure_dirs
  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "  ${BLUE}[dry-run]${RESET} Would install $item $ver → $tgt"
    cp -r --dry-run "$src" "$tgt" 2>/dev/null || true
    echo -e "${GREEN}✓${RESET} $item ${CYAN}$ver${RESET} installed (dry-run)"
  else
    cp -r "$src" "$tgt"
    echo -e "${GREEN}✓${RESET} $item ${CYAN}$ver${RESET} installed"
  fi
}

# ─── Upgrade ──────────────────────────────────────────────────────────────────

do_upgrade() {
  local item="$1" src="$2" tgt="$3" src_ver="$4" tgt_ver="$5"
  ensure_dirs
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local backup_path="$BACKUP_DIR/${item}-${ts}"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "  ${BLUE}[dry-run]${RESET} Would backup $tgt → $backup_path"
    echo -e "  ${BLUE}[dry-run]${RESET} Would copy $src → $tgt"
    echo -e "${GREEN}✓${RESET} $item ${CYAN}$tgt_ver${RESET} → ${CYAN}$src_ver${RESET} upgraded (dry-run)"
  else
    cp -r "$tgt" "$backup_path"
    rm -rf "$tgt"
    cp -r "$src" "$tgt" || {
      echo -e "${RED}Error: Install failed, restoring from backup${RESET}"
      rm -rf "$tgt"
      cp -r "$backup_path" "$tgt"
      exit 1
    }
    echo -e "${GREEN}✓${RESET} $item ${CYAN}$tgt_ver${RESET} → ${CYAN}$src_ver${RESET} upgraded (backup: ${backup_path})"
  fi
}

# ─── File Install ─────────────────────────────────────────────────────────────
# Single-file variant of do_install for flat-layout items (e.g. agent profiles
# deployed as <target>/<name>.md).
do_install_file() {
  local item="$1" src="$2" tgt="$3" ver="$4"
  ensure_dirs
  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "  ${BLUE}[dry-run]${RESET} Would install $item $ver → $tgt"
    echo -e "${GREEN}✓${RESET} $item ${CYAN}$ver${RESET} installed (dry-run)"
  else
    cp "$src" "$tgt"
    echo -e "${GREEN}✓${RESET} $item ${CYAN}$ver${RESET} installed"
  fi
}

# ─── File Upgrade ─────────────────────────────────────────────────────────────
# Single-file variant of do_upgrade. Backs up the target file to
# $BACKUP_DIR/<item>-<timestamp>.md (sibling backup, ADR-0003).
do_upgrade_file() {
  local item="$1" src="$2" tgt="$3" src_ver="$4" tgt_ver="$5"
  ensure_dirs
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local backup_path="$BACKUP_DIR/${item}-${ts}.md"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "  ${BLUE}[dry-run]${RESET} Would backup $tgt → $backup_path"
    echo -e "  ${BLUE}[dry-run]${RESET} Would copy $src → $tgt"
    echo -e "${GREEN}✓${RESET} $item ${CYAN}$tgt_ver${RESET} → ${CYAN}$src_ver${RESET} upgraded (dry-run)"
  else
    cp "$tgt" "$backup_path"
    cp "$src" "$tgt" || {
      echo -e "${RED}Error: Install failed, restoring from backup${RESET}"
      cp "$backup_path" "$tgt"
      exit 1
    }
    echo -e "${GREEN}✓${RESET} $item ${CYAN}$tgt_ver${RESET} → ${CYAN}$src_ver${RESET} upgraded (backup: ${backup_path})"
  fi
}
