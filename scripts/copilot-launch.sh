#!/usr/bin/env bash
#
# copilot-launch.sh — Scriptable launcher for GitHub Copilot sessions.
#
# Mirror of scripts/pi-launch.sh, but for the GitHub Copilot CLI and its
# deployed **agents** instead of pi's deployed role profiles. This is NOT a
# Manager — no lifecycle, no shared-library sourcing, no state, and no writes
# to the installed agents. It only reads them.
#
# Scriptable mode: given an agent name, resolve it against the INSTALLED
# agents directory (the Target) — flat `*.agent.md` files — and exec the
# interactive Copilot CLI with an `/agent <name>` selection as the session's
# FIRST INSTRUCTION. The agent's own instructions are what actually run.
#
# Modes:
#   copilot-launch.sh <agent>   Resolve the deployed agent and exec copilot
#   copilot-launch.sh           Interactively pick a deployed agent (or launch
#                               a plain session with no first instruction)
#
# Usage:
#   copilot-launch.sh <agent>   Launch a Copilot session for a deployed agent
#   copilot-launch.sh --help    Show usage
#
set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
if [[ -t 2 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
  BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BOLD=''; RESET=''
fi

# ─── Variables ────────────────────────────────────────────────────────────────
# COPILOT_HOME redirect: target dir = ${COPILOT_HOME:-~/.copilot}/agents.
# Default home location is ~/.copilot/agents.
COPILOT_HOME_DIR="${COPILOT_HOME:-${HOME}/.copilot}/agents"
AGENT_SELECTION_PREFIX="/agent "

# ─── Usage ────────────────────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage: copilot-launch.sh <agent>

Launch a GitHub Copilot session whose FIRST INSTRUCTION selects a deployed
agent (an `/agent <name>` slash command), then hands control to the interactive
Copilot session. The selected agent's own instructions are what run.

Arguments:
  <agent>             Name of a deployed agent. Resolved as a flat
                      <name>.agent.md file in the installed agents directory
                      (the Target). The frontmatter is not parsed.
  -h, --help          Show this usage message.

Resolution rules:
  Agents are resolved from the installed agents directory (the Target):
    ${COPILOT_HOME:-~/.copilot}/agents/<name>.agent.md
  The location may be redirected with the COPILOT_HOME environment variable:
    target dir = ${COPILOT_HOME:-~/.copilot}/agents
  The agent name is the filename minus the .agent.md suffix
  (e.g. analyst.agent.md -> analyst).
  The repo Source (copilot-agents/) is never consulted.

Examples:
  copilot-launch.sh analyst
  COPILOT_HOME=~/.copilot-2 copilot-launch.sh director
EOF
}

# ─── Agent resolution ─────────────────────────────────────────────────────────

# Resolve an agent name to its deployed agent file in the Target directory.
# Prints the resolved path on success; returns 1 if the file is missing.
resolve_agent_file() {
  local agent="$1"
  local file="${COPILOT_HOME_DIR}/${agent}.agent.md"

  if [[ -f "$file" ]]; then
    printf '%s\n' "$file"
    return 0
  fi
  return 1
}

# List deployed agent names (filenames minus the .agent.md suffix), sorted.
list_deployed_agents() {
  local f
  for f in "${COPILOT_HOME_DIR}"/*.agent.md; do
    [[ -f "$f" ]] || continue
    printf '%s\n' "$(basename "$f" .agent.md)"
  done | sort -u
}

# Plain-session marker. This is not a real agent; it starts a Copilot session
# with no first instruction.
PLAIN_SESSION_MARKER="no agent (plain session)"

# Print the chosen result. Reads the selection from stdin.
#
# With one or more deployed agents, shows a numbered list of them followed by
# a final plain-session entry; stdout carries the chosen agent name (empty
# for the plain-session entry).
#
# With zero deployed agents, prints a non-fatal warning to stderr and shows
# only the plain-session entry; stdout carries empty.
pick_agent() {
  local -a agents=()
  local agent
  while IFS= read -r agent; do
    [[ -n "$agent" ]] && agents+=("$agent")
  done < <(list_deployed_agents)

  # Zero deployed agents: warn (non-fatal) and offer only the plain session.
  if [[ ${#agents[@]} -eq 0 ]]; then
    echo -e "${YELLOW}Warning: no deployed agents found in ${COPILOT_HOME_DIR}. Starting a plain Copilot session.${RESET}" >&2
    echo -e "  1. ${PLAIN_SESSION_MARKER}" >&2
    local choice
    read -r -p "Select an option [1]: " choice
    if [[ "$choice" != "1" ]]; then
      echo -e "${RED}Error: Invalid selection: ${choice}${RESET}" >&2
      exit 1
    fi
    return 0
  fi

  local entry_count=${#agents[@]}
  # Append the plain-session entry. Total menu entries = agents + 1.
  entry_count=$((entry_count + 1))

  # Menu goes to stderr so stdout carries only the chosen result.
  echo -e "${BOLD}Choose a Copilot agent:${RESET}" >&2
  local i
  for i in "${!agents[@]}"; do
    echo -e "  $((i + 1)). ${agents[$i]}" >&2
  done
  echo -e "  ${entry_count}. ${PLAIN_SESSION_MARKER}" >&2

  local choice
  read -r -p "Select an agent [1-${entry_count}]: " choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: Invalid selection: ${choice}${RESET}" >&2
    exit 1
  fi
  # Normalize to decimal so leading zeros (e.g. 08) are not read as octal.
  local normalized=$((10#$choice))
  if (( normalized < 1 || normalized > entry_count )); then
    echo -e "${RED}Error: Invalid selection: ${choice}${RESET}" >&2
    exit 1
  fi
  choice=$normalized

  # Agent entries: 1..N. The plain-session entry (N+1) yields an empty name.
  if (( choice == entry_count )); then
    return 0
  fi
  printf '%s\n' "${agents[$((choice - 1))]}"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

# Bare invocation: enter interactive picker mode.
# With an agent argument, resolve it and exec copilot with an /agent selection.
# No flag passthrough.
if [[ -z "${1:-}" ]]; then
  CHOICE="$(pick_agent)"
else
  CHOICE="$1"
fi

# Empty result: plain session — bare interactive start, no first instruction.
if [[ -z "$CHOICE" ]]; then
  echo -e "${GREEN}${BOLD}Launching a plain Copilot session (no agent).${RESET}" >&2
  exec copilot
fi

AGENT="$CHOICE"

if ! AGENT_FILE="$(resolve_agent_file "$AGENT")"; then
  AVAILABLE="$(list_deployed_agents)"
  echo -e "${RED}Error: no deployed agent named '${AGENT}'${RESET}" >&2
  echo -e "Tried: ${COPILOT_HOME_DIR}/${AGENT}.agent.md" >&2
  if [[ -z "$AVAILABLE" ]]; then
    echo -e "Available agents: (none found in ${COPILOT_HOME_DIR})" >&2
  else
    # Comma-join the newline-separated names (paste's delimiter string cycles
    # char-by-char, so build the list by hand instead).
    COMMA_JOINED=""
    while IFS= read -r name; do
      if [[ -z "$COMMA_JOINED" ]]; then
        COMMA_JOINED="$name"
      else
        COMMA_JOINED="${COMMA_JOINED}, ${name}"
      fi
    done <<< "$AVAILABLE"
    echo -e "Available agents: ${COMMA_JOINED}" >&2
  fi
  exit 1
fi

echo -e "${GREEN}${BOLD}Launching Copilot with agent: ${AGENT} (${AGENT_FILE})${RESET}" >&2

exec copilot -i "${AGENT_SELECTION_PREFIX}${AGENT}"
