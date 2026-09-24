#!/usr/bin/env bash
#
# ledger-manager.sh — Deploy and maintain the Ticket Ledger workspace
#
# The source repo (this repo) is the source; the target directory is a generated
# artifact. One-way sync. A manifest file present in the target is never
# overwritten: install-if-missing + drift warning; --reinstall is the only
# adoption path (timestamped backup in the sibling <target>.backups/, then
# replace). Files not in the manifest — all user content — are never touched
# by any command.
#
set -euo pipefail

# ─── Source Shared Library ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/agent-manager-lib.sh"

# ─── Manager-Specific Variables ───────────────────────────────────────────────
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKELETON_DIR="${REPO_ROOT}/ledger"
MANIFEST="${SKELETON_DIR}/manifest.json"
GLOBAL_SKILLS_DIR="${HOME}/.agents/skills"

# ─── Ledger-Specific Usage ────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage: ledger-manager.sh <command> [options] [args]

Commands:
  deploy <target-dir>           Deploy the ledger skeleton into a fresh directory
  upgrade <target-dir>          Reconcile an existing ledger target (install-if-missing, drift warnings)
  status <target-dir>           Report marker provenance, per-file state, and skill checks
  list                          Show the manifest (scaffolding files + skill check-list)

Options:
  --reinstall, -f               Adopt drifted manifest files (timestamped backup in <target>.backups/, then replace)
  --dry-run, -n                 Preview changes without making them
  --help, -h                    Show usage

Notes:
  deploy on an existing ledger target (marker present) behaves identically to
  upgrade — one code path, two names. The manager never installs, upgrades, or
  uninstalls global skills — it only checks and warns.
EOF
}

# ─── Manifest helpers ─────────────────────────────────────────────────────────

# Print manifest entries as "source_path<TAB>target_path" lines. The target
# path differs from the source path for the remember skill (deployed into the
# target's .agents/skills/ so Copilot picks it up from the root) and the
# ticket-ledger agent (deployed into the target's .github/agents/ with the
# .agent.md extension — Copilot CLI's project-level agent discovery location;
# the workspace is a Copilot environment).
manifest_entries() {
  python3 - "$MANIFEST" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    m = json.load(f)
remap = {
    "skills/remember/SKILL.md": ".agents/skills/remember/SKILL.md",
    "agents/ticket-ledger.md": ".github/agents/ticket-ledger.agent.md",
}
for p in m["files"]:
    print(f"{p}\t{remap.get(p, p)}")
PY
}

# Print one manifest list field, one entry per line.
manifest_field() {
  python3 - "$MANIFEST" "$1" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    m = json.load(f)
for e in m.get(sys.argv[2], []):
    print(e)
PY
}

# ─── Marker helpers ───────────────────────────────────────────────────────────

marker_path() { echo "$1/deployed-from"; }

marker_commit() {
  local marker="$1"
  [[ -f "$marker" ]] || return 0
  sed -n 's/^commit:[[:space:]]*//p' "$marker" | head -n1
}

write_marker() {
  local target="$1"
  local commit date
  commit="$(git -C "$REPO_ROOT" rev-parse HEAD)"
  date="$(date +%Y-%m-%d)"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "  ${BLUE}[dry-run]${RESET} Would write marker → $target/deployed-from (commit $commit, $date)"
  else
    printf 'commit: %s\ndate: %s\n' "$commit" "$date" > "$target/deployed-from"
    echo -e "${GREEN}✓${RESET} Marker written: commit ${CYAN}${commit:0:8}${RESET}, ${date}"
  fi
}

# ─── State helpers (per-file install hashes) ──────────────────────────────────
# One state dotfile per manifest file, in the sibling <target>.backups/
# directory (ADR-0003) — never inside the target, so the target's write
# surface stays exactly the manifest files. The shared lib's drift helpers
# (sha256_of, classify_state, print_drift_diff) operate on these directly.
state_file_for() { echo "$1.backups/$2.sha256"; }

# ─── Skill checks ─────────────────────────────────────────────────────────────

# Check the global skill set; warn (never install) for any missing.
check_global_skills() {
  local skill
  while IFS= read -r skill; do
    [[ -n "$skill" ]] || continue
    if [[ -d "${GLOBAL_SKILLS_DIR}/${skill}" ]]; then
      echo -e "  ${GREEN}✓${RESET} skill ${CYAN}$skill${RESET} present"
    else
      echo -e "  ${YELLOW}⚠${RESET} skill ${CYAN}$skill${RESET} missing — install with: ${CYAN}scripts/skill-manager.sh install $skill${RESET}"
    fi
  done < <(manifest_field skill_check_list)
}

# ─── Per-file state ───────────────────────────────────────────────────────────
# Describe one manifest file's state against the skeleton. Prints one of:
# missing-src | not-installed | up-to-date | drift:<state>
#   $1 — target dir   $2 — source rel path   $3 — target rel path
file_state() {
  local target="$1" src_rel="$2" tgt_rel="$3"
  local src="${SKELETON_DIR}/${src_rel}"
  local tgt="${target}/${tgt_rel}"
  if [[ ! -f "$src" ]]; then
    echo "missing-src"
    return 0
  fi
  if [[ ! -f "$tgt" ]]; then
    echo "not-installed"
    return 0
  fi
  local src_hash tgt_hash
  src_hash="$(sha256_of "$src")"
  tgt_hash="$(sha256_of "$tgt")"
  if [[ "$src_hash" == "$tgt_hash" ]]; then
    echo "up-to-date"
    return 0
  fi
  echo "drift:$(classify_state "$src_hash" "$tgt_hash" "$(state_file_for "$target" "$src_rel")")"
}

# ─── Per-file reconciliation ──────────────────────────────────────────────────
# Reconcile one manifest file: install if missing; warn on drift; adopt only
# with --reinstall (timestamped backup in the sibling <target>.backups/, then
# replace).
reconcile_file() {
  local target="$1" src_rel="$2" tgt_rel="$3"
  local src="${SKELETON_DIR}/${src_rel}"
  local tgt="${target}/${tgt_rel}"
  local state_file
  state_file="$(state_file_for "$target" "$src_rel")"

  local state
  state="$(file_state "$target" "$src_rel" "$tgt_rel")"
  case "$state" in
    missing-src)
      echo -e "${RED}✗${RESET} manifest lists ${CYAN}$src_rel${RESET} but it is missing from the skeleton: $src"
      return 1 ;;
    up-to-date)   echo -e "  ${GREEN}✓${RESET} up-to-date ${CYAN}$tgt_rel${RESET}"; return 0 ;;
  esac

  local src_hash
  src_hash="$(sha256_of "$src")"

  if [[ ! -f "$tgt" ]]; then
    # Install-if-missing.
    if [[ $DRY_RUN -eq 1 ]]; then
      echo -e "  ${BLUE}[dry-run]${RESET} Would install ${CYAN}$tgt_rel${RESET}"
    else
      mkdir -p "$(dirname "$tgt")"
      cp "$src" "$tgt"
      mkdir -p "$(dirname "$state_file")"
      printf '%s\n' "$src_hash" > "$state_file"
      echo -e "${GREEN}✓${RESET} installed ${CYAN}$tgt_rel${RESET}"
    fi
    return 0
  fi

  # Target differs from the skeleton (drift).
  if [[ $FORCE -eq 1 ]]; then
    local ts backup
    ts="$(date +%Y%m%d-%H%M%S)"
    backup="${target}.backups/$(basename "$tgt_rel")-${ts}"
    if [[ $DRY_RUN -eq 1 ]]; then
      echo -e "  ${BLUE}[dry-run]${RESET} Would reinstall ${CYAN}$tgt_rel${RESET} (backup → ${backup})"
    else
      mkdir -p "$(dirname "$backup")"
      cp "$tgt" "$backup"
      cp "$src" "$tgt"
      mkdir -p "$(dirname "$state_file")"
      printf '%s\n' "$src_hash" > "$state_file"
      echo -e "${GREEN}✓${RESET} reinstalled ${CYAN}$tgt_rel${RESET} (backup: ${backup})"
    fi
    return 0
  fi

  echo -e "  ${YELLOW}⚠${RESET} drift (${state#drift:}): ${CYAN}$tgt_rel${RESET} differs from the skeleton — not overwritten"
  print_drift_diff "$tgt" "$src"
  echo -e "  ${YELLOW}Adopt with: ledger-manager.sh ${COMMAND} ${target} --reinstall${RESET}"
  return 0
}

# ─── Foreign-target guard ─────────────────────────────────────────────────────
# deploy hard-fails on a non-empty directory that is neither a git repository
# nor a prior ledger deploy (marker present).
guard_foreign_target() {
  local target="$1"
  [[ -d "$target" ]] || return 0
  if [[ -f "$(marker_path "$target")" || -d "${target}/.git" ]]; then
    return 0
  fi
  if [[ -n "$(ls -A "$target" 2>/dev/null)" ]]; then
    echo -e "${RED}Error: ${target} is a non-empty directory that is neither a git repository nor a prior ledger deploy.${RESET}"
    echo -e "${RED}Refusing to seed scaffolding into an unknown foreign directory.${RESET}"
    exit 1
  fi
  return 0
}

# ─── Local-git backstop ───────────────────────────────────────────────────────
# git init if not already a repo; initial commit of the deployed scaffolding.
# No remote, ever; the manager never pushes, adds remotes, or edits
# .git/config beyond init.
ensure_git_repo() {
  local target="$1"
  # git init if not already a repo; make the initial commit of the deployed
  # scaffolding (scaffolding paths only, never user content). A repo that
  # already has commits is left alone — the manager never auto-commits user
  # content on a later run.
  if [[ -d "${target}/.git" ]] && git -C "$target" rev-parse --verify HEAD >/dev/null 2>&1; then
    return 0
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "  ${BLUE}[dry-run]${RESET} Would git init ${target} and make the initial commit"
    return 0
  fi
  [[ -d "${target}/.git" ]] || git -C "$target" init -q
  # Commit only the deployed scaffolding, not any pre-existing user content:
  # stage the scaffolding paths and commit exactly those paths.
  local rel paths=()
  while IFS=$'\t' read -r _ rel; do
    [[ -n "$rel" ]] || continue
    git -C "$target" add -- "$rel"
    paths+=("$rel")
  done < <(manifest_entries)
  git -C "$target" -c user.name="${GIT_AUTHOR_NAME:-Ledger}" \
      -c user.email="${GIT_AUTHOR_EMAIL:-ledger@local}" \
      commit -q -m "Initial ledger deploy (commit $(git -C "$REPO_ROOT" rev-parse --short HEAD))" -- "${paths[@]}"
  echo -e "${GREEN}✓${RESET} git repository initialized with initial commit"
}

# ─── Advisory: uncommitted user content ──────────────────────────────────────
advise_uncommitted() {
  local target="$1"
  [[ -d "${target}/.git" ]] || return 0
  local n
  n="$(git -C "$target" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$n" -gt 0 ]]; then
    echo -e "  ${YELLOW}⚠${RESET} advisory: ${n} user-content file(s) changed since last deploy; commit them yourself"
  fi
}

# ─── Reconcile all manifest files ─────────────────────────────────────────────
reconcile_all() {
  local target="$1" src_rel tgt_rel failed=0
  while IFS=$'\t' read -r src_rel tgt_rel; do
    [[ -n "$src_rel" ]] || continue
    reconcile_file "$target" "$src_rel" "$tgt_rel" || failed=1
  done < <(manifest_entries)
  if [[ $failed -eq 1 ]]; then
    exit 1
  fi
}

# ─── Commands ─────────────────────────────────────────────────────────────────

# One code path, two names: deploy and upgrade share this function. A fresh
# target (no marker) runs the deploy steps (guard, mkdir, git init); an
# existing ledger target runs the upgrade steps (advisory). Both then run the
# identical reconcile + marker + skill-check tail.
cmd_deploy_upgrade() {
  local target="$1"
  [[ -n "$target" ]] || { echo -e "${RED}Error: ${COMMAND} requires <target-dir>${RESET}"; usage; exit 1; }
  target="${target%/}"

  if [[ -f "$(marker_path "$target")" ]]; then
    if [[ "$COMMAND" == "deploy" ]]; then
      echo -e "${BLUE}Existing ledger target detected — deploy behaves as upgrade.${RESET}"
    fi
    advise_uncommitted "$target"
  else
    if [[ "$COMMAND" == "upgrade" ]]; then
      echo -e "${RED}Error: ${target} is not a ledger target (no deployed-from marker). Use deploy first.${RESET}"
      exit 1
    fi
    guard_foreign_target "$target"
    [[ $DRY_RUN -eq 0 ]] && mkdir -p "$target"
  fi

  reconcile_all "$target"
  ensure_git_repo "$target"
  write_marker "$target"
  check_global_skills
  echo -e "${GREEN}✓${RESET} ${COMMAND} complete: ${target}"
}

cmd_status() {
  local target="$1"
  [[ -n "$target" ]] || { echo -e "${RED}Error: status requires <target-dir>${RESET}"; usage; exit 1; }
  target="${target%/}"

  if [[ ! -d "$target" ]]; then
    echo -e "${RED}Error: ${target} does not exist${RESET}"
    exit 1
  fi

  local marker commit current
  marker="$(marker_path "$target")"
  if [[ -f "$marker" ]]; then
    commit="$(marker_commit "$marker")"
    current="$(git -C "$REPO_ROOT" rev-parse HEAD)"
    echo -e "${BOLD}Target:${RESET} ${target}"
    echo -e "${BOLD}Deployed from:${RESET} ${CYAN}${commit:-unknown}${RESET}"
    if [[ -n "$commit" && "$commit" == "$current" ]]; then
      echo -e "${BOLD}Source commit:${RESET} ${GREEN}up-to-date${RESET}"
    else
      echo -e "${BOLD}Source commit:${RESET} ${YELLOW}${current:0:8}${RESET} (target deployed from ${commit:0:8})"
    fi
  else
    echo -e "${BOLD}Target:${RESET} ${target}"
    echo -e "${YELLOW}⚠${RESET} no deployed-from marker — not a ledger target"
  fi

  echo ""
  echo -e "${BOLD}Manifest files:${RESET}"
  local src_rel tgt_rel state
  while IFS=$'\t' read -r src_rel tgt_rel; do
    [[ -n "$src_rel" ]] || continue
    state="$(file_state "$target" "$src_rel" "$tgt_rel")"
    case "$state" in
      missing-src)   echo -e "  ${RED}✗${RESET} ${tgt_rel} — missing from skeleton" ;;
      not-installed) echo -e "  ${CYAN}→${RESET} ${tgt_rel} — not installed" ;;
      up-to-date)    echo -e "  ${GREEN}✓${RESET} ${tgt_rel} — up-to-date" ;;
      drift:*)       echo -e "  ${YELLOW}⚠${RESET} ${tgt_rel} — drift (${state#drift:})" ;;
    esac
  done < <(manifest_entries)

  echo ""
  echo -e "${BOLD}Global skill checks:${RESET}"
  check_global_skills
}

cmd_list() {
  echo -e "${BOLD}Manifest:${RESET} ${MANIFEST}"
  echo ""
  echo -e "${BOLD}Scaffolding files:${RESET}"
  local src_rel tgt_rel
  while IFS=$'\t' read -r src_rel tgt_rel; do
    [[ -n "$src_rel" ]] || continue
    if [[ "$src_rel" == "$tgt_rel" ]]; then
      echo "  $src_rel"
    else
      echo "  $src_rel → $tgt_rel"
    fi
  done < <(manifest_entries)
  echo ""
  echo -e "${BOLD}Global skill check-list:${RESET}"
  manifest_field skill_check_list | sed 's/^/  /'
}

# ─── Main ─────────────────────────────────────────────────────────────────────

parse_args "$@"

case "$COMMAND" in
  deploy)  cmd_deploy_upgrade "$ITEM_NAME" ;;
  upgrade) cmd_deploy_upgrade "$ITEM_NAME" ;;
  status)  cmd_status "$ITEM_NAME" ;;
  list)    cmd_list ;;
  *)
    echo -e "${RED}Unknown command: $COMMAND${RESET}"
    usage
    exit 1
    ;;
esac
