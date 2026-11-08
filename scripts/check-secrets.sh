#!/usr/bin/env bash
#
# check-secrets.sh — hard gate: never commit credentials (AGENTS.md §Credentials).
#
# Scans staged changes (git diff --cached, added lines only) for credential
# patterns. Run before every commit; a match blocks the commit until the
# secret moves to a per-install gitignored file or an environment
# variable.
#
# Patterns:
#   1. Token prefixes: github_pat_, gh[pousr]_ (classic/OAuth PATs),
#      glpat- (GitLab), xox[abprs]- (Slack), sk- (OpenAI-style).
#   2. Key/value secrets: apiKey/api_key/token/password/secret with a
#      real-looking value (>= 8 chars), excluding obvious placeholders.
#
# Exit 0 = clean, 1 = potential credential found, 2 = usage/environment error.

set -u

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "check-secrets: not a git repository" >&2
  exit 2
fi

diff_output="$(git diff --cached)"
if [[ -z "$diff_output" ]]; then
  echo "check-secrets: no staged changes"
  exit 0
fi

# Added lines only (drop the +++ file header).
added="$(printf '%s\n' "$diff_output" | grep '^+' | grep -v '^+++' || true)"
if [[ -z "$added" ]]; then
  echo "check-secrets: no added lines"
  exit 0
fi

found=0

# 1. Token prefixes.
if printf '%s\n' "$added" | grep -nE 'github_pat_[A-Za-z0-9]+|gh[pousr]_[A-Za-z0-9]{16,}|glpat-[A-Za-z0-9_-]{8,}|xox[abprs]-[A-Za-z0-9-]{8,}|sk-[A-Za-z0-9]{16,}'; then
  found=1
fi

# 2. Key/value secrets with real-looking values (not placeholders).
if printf '%s\n' "$added" | grep -inE "(api[_-]?key|auth[_-]?token|access[_-]?token|password|passwd|secret)[\"']?[[:space:]]*[:=][[:space:]]*[\"']?[A-Za-z0-9_-]{8,}" \
   | grep -viE 'your[-_]|<[^>]*>|\$\{|example|placeholder|none|null|empty|changeme|x{3,}|todo|your-|redacted|xxx'; then
  found=1
fi

if [[ $found -eq 1 ]]; then
  echo ""
  echo "check-secrets: potential credential(s) in staged changes (matches above)."
  echo "Secrets belong in per-install gitignored files or environment"
  echo "variables — never in committed files."
  exit 1
fi

echo "check-secrets: clean"
exit 0
