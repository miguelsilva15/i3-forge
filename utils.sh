#!/usr/bin/env bash
# utils.sh — shared logging, error handling, and retry logic for i3-forge
# Source this at the top of every script: source "$(dirname "$0")/utils.sh"

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────────────
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFESTS_DIR="$REPO_DIR/manifests"
DOTFILES_DIR="$REPO_DIR/dotfiles"
SCRIPTS_DIR="$REPO_DIR/scripts"
LOG_DIR="$HOME/.i3-forge"
LOG_FILE="$LOG_DIR/restore.log"
FAILED_LOG="$LOG_DIR/failures.log"

mkdir -p "$LOG_DIR"

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── Logging ──────────────────────────────────────────────────────────────────
_timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

log_info()    { echo -e "${BLUE}[INFO]${NC}  $(_timestamp) $*" | tee -a "$LOG_FILE"; }
log_ok()      { echo -e "${GREEN}[  OK]${NC}  $(_timestamp) $*" | tee -a "$LOG_FILE"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $(_timestamp) $*" | tee -a "$LOG_FILE"; }
log_error()   { echo -e "${RED}[FAIL]${NC}  $(_timestamp) $*" | tee -a "$LOG_FILE"; }
log_section() { echo -e "\n${BOLD}${CYAN}══════ $* ══════${NC}\n" | tee -a "$LOG_FILE"; }

# ── Failure tracking ─────────────────────────────────────────────────────────
# Instead of aborting on error, we log failures and continue.
# At the end, summarize what failed.

FAILURE_COUNT=0

track_failure() {
    local component="$1"
    local detail="$2"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
    echo "$(_timestamp) [$component] $detail" >> "$FAILED_LOG"
    log_error "$component: $detail"
}

summarize_failures() {
    echo ""
    if [[ "$FAILURE_COUNT" -eq 0 ]]; then
        log_ok "All steps completed successfully!"
    else
        log_warn "$FAILURE_COUNT failure(s) occurred. Details in: $FAILED_LOG"
        echo -e "${YELLOW}──── Failed items ────${NC}"
        cat "$FAILED_LOG"
        echo -e "${YELLOW}──────────────────────${NC}"
    fi
}

# ── Retry logic ──────────────────────────────────────────────────────────────
# Usage: retry 3 some_command --with-args
retry() {
    local max_attempts="$1"
    shift
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if "$@"; then
            return 0
        fi
        log_warn "Attempt $attempt/$max_attempts failed: $*"
        attempt=$((attempt + 1))
        sleep 2
    done

    return 1
}

# ── Idempotency helpers ─────────────────────────────────────────────────────
is_pkg_installed() {
    rpm -q "$1" &>/dev/null
}

is_flatpak_installed() {
    flatpak list --app --columns=application 2>/dev/null | grep -q "^${1}$"
}

command_exists() {
    command -v "$1" &>/dev/null
}

# ── Confirmation prompt ──────────────────────────────────────────────────────
confirm() {
    local prompt="${1:-Continue?}"
    echo -en "${YELLOW}${prompt} [y/N] ${NC}"
    read -r reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

# ── Clean up traps ───────────────────────────────────────────────────────────
_cleanup() {
    # Reset terminal colors in case we exit mid-output
    echo -en "$NC"
}
trap _cleanup EXIT
