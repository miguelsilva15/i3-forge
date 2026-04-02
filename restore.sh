#!/usr/bin/env bash
# restore.sh — full system restore, runs all layers in order
# Usage: ./scripts/restore.sh [--only dnf|flatpak|source|dotfiles]

source "$(dirname "$0")/utils.sh"

ONLY="${1:-}"

# Strip --only prefix if present
if [[ "$ONLY" == "--only" ]]; then
    ONLY="${2:-}"
fi

run_step() {
    local name="$1"
    local script="$2"

    # If --only was specified, skip non-matching steps
    if [[ -n "$ONLY" ]] && [[ "$ONLY" != "$name" ]]; then
        return
    fi

    log_section "Step: $name"

    if [[ ! -f "$script" ]]; then
        track_failure "$name" "Script not found: $script"
        return
    fi

    # Run in a subshell so failures don't kill the whole restore
    (
        bash "$script"
    ) || {
        track_failure "$name" "Step exited with error (check logs above)"
    }
}

# ══════════════════════════════════════════════════════════════════════════════

log_section "i3-forge System Restore"
log_info "Starting at $(date)"
log_info "Logs: $LOG_FILE"
log_info "Failure log: $FAILED_LOG"

> "$FAILED_LOG"  # Reset failure log

echo ""
if [[ -n "$ONLY" ]]; then
    log_info "Running only: $ONLY"
else
    log_info "Running full restore: dnf → flatpak → source → dotfiles"
fi
echo ""

if ! confirm "This will install packages and symlink dotfiles. Continue?"; then
    log_info "Aborted by user."
    exit 0
fi

# ── Run layers in order ─────────────────────────────────────────────────────
run_step "dnf"      "$SCRIPTS_DIR/install-dnf.sh"
run_step "flatpak"  "$SCRIPTS_DIR/install-flatpak.sh"
run_step "source"   "$SCRIPTS_DIR/install-source.sh"
run_step "dotfiles" "$SCRIPTS_DIR/link-dotfiles.sh"

# ══════════════════════════════════════════════════════════════════════════════

log_section "Restore Complete"
log_info "Finished at $(date)"

summarize_failures

echo ""
log_info "You may need to:"
echo "  → Log out and back in for shell changes to take effect"
echo "  → Restart i3 (Mod+Shift+R) for config changes"
echo "  → Check docs/post-install-notes.md for manual steps"
echo ""
