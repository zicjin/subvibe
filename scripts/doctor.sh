#!/usr/bin/env bash
#
# doctor.sh — read-only health check for subvibe (subagent delegation plugin).
# Verifies executor CLIs (default: grok; optional: agy) and that the plugin is
# wired up (scripts executable).
#
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ok()   { printf '  ✓ %s\n' "$*"; }
bad()  { printf '  ✗ %s\n' "$*"; FAIL=1; }
warn() { printf '  ⚠ %s\n' "$*"; }   # advisory; does NOT fail the check
info() { printf '    %s\n' "$*"; }
FAIL=0

# Resolve a usable `timeout` command (GNU coreutils, or macOS Homebrew gtimeout)
# so a headless/no-TTY hang in CLI probes is bounded instead of freezing doctor.
TO_CMD=""
if   command -v timeout  >/dev/null 2>&1; then TO_CMD=timeout
elif command -v gtimeout >/dev/null 2>&1; then TO_CMD=gtimeout
fi
# Run a CLI with a wall-clock guard when possible. Returns the CLI's exit code, or
# the `timeout` kill code (124 SIGTERM / 137 SIGKILL) when it had to kill a hang.
cli_guard() { # usage: cli_guard <secs> <bin> <args...>
  local secs="$1"; shift
  if [ -n "$TO_CMD" ]; then
    "$TO_CMD" --kill-after=5 "$secs" "$@"
    return $?
  fi
  "$@"
}

# True on native Windows (Git Bash/MSYS/Cygwin), NOT WSL — where headless CLIs hang.
on_windows_native() {
  case "${OSTYPE:-}" in msys*|cygwin*|win32) return 0 ;; esac
  case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*) return 0 ;; esac
  return 1
}

DEFAULT_DRIVER="${SUBVIBE_DRIVER:-grok}"
echo "subvibe — doctor (default driver: $DEFAULT_DRIVER)"
echo ""

# 1. plugin scripts executable
echo "Plugin scripts"
for s in subvibe-delegate.sh subvibe-job.sh doctor.sh; do
  if [ -x "$HERE/$s" ]; then ok "$s executable"; else
    bad "$s not executable"; info "fix: chmod +x \"$HERE/$s\""
  fi
done
# drivers present
for d in agy grok; do
  if [ -f "$HERE/drivers/$d.sh" ]; then ok "driver present: $d"; else
    bad "driver missing: drivers/$d.sh"
  fi
done
echo ""

# 2. Grok Build CLI (default driver)
echo "Driver: grok (Grok Build)"
if command -v grok >/dev/null 2>&1; then
  ok "grok found: $(command -v grok)  ($(cli_guard 10 grok --version 2>/dev/null | head -1))"
  if [ -z "$TO_CMD" ]; then
    warn "no \`timeout\`/\`gtimeout\` on PATH — cannot bound a possible headless hang"
    info "install coreutils \`timeout\` (or Homebrew \`gtimeout\`) so doctor can tell a hang from an auth failure"
  fi
  # Unauthenticated headless grok can hang; bound the probe.
  GROK_OUT="$(cli_guard 20 grok models 2>/dev/null)"; GROK_RC=$?
  GROK_TIMED_OUT=0
  { [ "$GROK_RC" -eq 124 ] || [ "$GROK_RC" -eq 137 ]; } && GROK_TIMED_OUT=1
  if [ "$GROK_TIMED_OUT" -eq 1 ]; then
    bad "\`grok models\` hung and was killed after 20s — often means not authenticated"
    info "run \`grok login\` (or set XAI_API_KEY). Unauthenticated headless grok hangs instead of failing."
  elif [ -n "$GROK_OUT" ]; then
    ok "grok authenticated — models list returned output"
    LOW="${GROK_TIER_LOW:-grok-composer-2.5-fast}"
    MEDIUM="${GROK_TIER_MEDIUM:-grok-4.5}"
    HIGH="${GROK_TIER_HIGH:-grok-4.5}"
    for m in "$LOW" "$MEDIUM" "$HIGH"; do
      if printf '%s' "$GROK_OUT" | grep -qF "$m"; then
        ok "tier model present: $m"
      else
        warn "tier model not in 'grok models': $m"
        info "remap via GROK_TIER_* (or set SUBVIBE_DEFAULT_MODEL), or pass --model <name from \`grok models\`>"
      fi
    done
  else
    bad "grok could not list models (not authenticated, or no network)"
    info "fix: run \`grok login\` (or set XAI_API_KEY)"
  fi
else
  if [ "$DEFAULT_DRIVER" = "grok" ]; then
    bad "grok NOT on PATH (default driver)"
    info "fix: install Grok Build — curl -fsSL https://x.ai/cli/install.sh | bash"
  else
    warn "grok NOT on PATH (not the default driver; OK if you only use agy)"
  fi
fi
echo ""

# 3. Antigravity CLI (optional driver)
echo "Driver: agy (Antigravity)"
if command -v agy >/dev/null 2>&1; then
  ok "agy found: $(command -v agy)  ($(cli_guard 10 agy --version 2>/dev/null | head -1))"
  if [ -z "$TO_CMD" ]; then
    warn "no \`timeout\`/\`gtimeout\` on PATH — cannot bound a possible \`agy models\` hang"
  fi
  MODELS="$(cli_guard 20 agy models 2>/dev/null)"; AGY_RC=$?
  AGY_TIMED_OUT=0
  { [ "$AGY_RC" -eq 124 ] || [ "$AGY_RC" -eq 137 ]; } && AGY_TIMED_OUT=1
  if [ "$AGY_TIMED_OUT" -eq 1 ]; then
    bad "\`agy models\` hung and was killed after 20s — this is NOT an auth problem"
    info "agy hangs when run headless with no TTY/console (0-byte log, no output)."
    if on_windows_native; then
      info "native Windows: agy needs a real console (ConPTY). Run delegation from WSL/macOS/Linux."
    else
      info "check whether agy is being invoked without a console; prefer WSL/macOS/Linux for headless delegation."
    fi
    info "(your credentials are likely fine — don't re-authenticate based on this.)"
    MODELS=""
  fi
  if [ -n "$MODELS" ]; then
    ok "agy authenticated — $(printf '%s' "$MODELS" | grep -c . ) models available"
    # configured tier->model names exist (respecting env remaps). agy is
    # multi-model and plan-dependent, so a miss is a WARNING, not a failure.
    LOW="${AGY_TIER_LOW:-Gemini 3.5 Flash (Low)}"
    MEDIUM="${AGY_TIER_MEDIUM:-Gemini 3.5 Flash (Medium)}"
    HIGH="${AGY_TIER_HIGH:-Gemini 3.5 Flash (High)}"
    for m in "$LOW" "$MEDIUM" "$HIGH"; do
      if printf '%s' "$MODELS" | grep -qF "$m"; then
        ok "tier model present: $m"
      else
        warn "tier model not in 'agy models': $m"
        info "agy is multi-model/plan-dependent — remap tiers via AGY_TIER_* (or set SUBVIBE_DEFAULT_MODEL), or pass --model <name from \`agy models\`>"
      fi
    done
  elif [ "$AGY_TIMED_OUT" -eq 0 ]; then
    if [ "$DEFAULT_DRIVER" = "agy" ]; then
      bad "agy could not list models (not authenticated, or no network)"
    else
      warn "agy could not list models (not authenticated, or no network)"
    fi
    info "fix: authenticate agy (run \`agy\` once interactively) and check GCP access"
    info "if agy works interactively but is empty here, suspect a headless/no-TTY hang instead (see above)"
  fi
  # agy GCP config
  SETTINGS="$HOME/.gemini/antigravity-cli/settings.json"
  if [ -f "$SETTINGS" ]; then
    PROJ="$(sed -n 's/.*"project"[: ]*"\([^"]*\)".*/\1/p' "$SETTINGS" | head -1)"
    LOC="$(sed -n 's/.*"location"[: ]*"\([^"]*\)".*/\1/p' "$SETTINGS" | head -1)"
    ok "agy settings: ${SETTINGS/#$HOME/~}"
    [ -n "$PROJ" ] && info "GCP project: $PROJ   location: ${LOC:-?}"
  else
    info "no agy settings.json yet (${SETTINGS/#$HOME/~})"
  fi
else
  if [ "$DEFAULT_DRIVER" = "agy" ]; then
    bad "agy NOT on PATH (default driver via SUBVIBE_DRIVER=agy)"
    info "fix: install the Antigravity CLI, then ensure its bin dir is on PATH"
  else
    warn "agy NOT on PATH (optional; install only if you want --driver agy)"
  fi
fi
echo ""

# 4. WSL: --add-dir over a Windows mount (/mnt/*) is slow for agy (9p bridge)
if grep -qi microsoft /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]; then
  echo "Environment"
  case "$PWD" in
    /mnt/*)
      warn "WSL + workspace on a Windows mount ($PWD)"
      info "agy --add-dir reads this over a slow 9p bridge (calls can take 20s+)."
      info "fix: move the repo into the WSL Linux filesystem (e.g. ~/projects) for ~10x faster I/O" ;;
    *) ok "WSL detected; workspace is on the Linux filesystem" ;;
  esac
  echo ""
fi

if [ "$FAIL" -eq 0 ]; then echo "All checks passed — ready to delegate."; else
  echo "Some checks failed — see fixes above."; fi
exit "$FAIL"
