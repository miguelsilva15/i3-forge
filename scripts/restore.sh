#!/usr/bin/env bash
source "$(dirname "$0")/utils.sh"

ONLY="${1:-}"
[[ "$ONLY" == "--only" ]] && ONLY="${2:-}"

run_step() {
    local name="$1" script="$2"
    [[ -n "$ONLY" ]] && [[ "$ONLY" != "$name" ]] && return
    log_section "Step: $name"
    [[ ! -f "$script" ]] && { track_failure "$name" "Script not found: $script"; return; }
    ( bash "$script" ) || track_failure "$name" "Step exited with error"
}

log_section "i3-forge System Restore"
log_info "Starting at $(date)"
> "$FAILED_LOG"

if [[ -n "$ONLY" ]]; then log_info "Running only: $ONLY"
else log_info "Running full restore: dnf → flatpak → source → dotfiles"; fi

confirm "This will install packages and symlink dotfiles. Continue?" || { log_info "Aborted."; exit 0; }

run_step "dnf"      "$SCRIPTS_DIR/install-dnf.sh"
run_step "flatpak"  "$SCRIPTS_DIR/install-flatpak.sh"
run_step "source"   "$SCRIPTS_DIR/install-source.sh"
run_step "dotfiles" "$SCRIPTS_DIR/link-dotfiles.sh"

log_section "Restore Complete"
summarize_failures
echo ""
log_info "You may need to:"
echo "  → Log out and back in for shell changes"
echo "  → Restart i3 (Mod+Shift+R) for config changes"
echo "  → Check docs/post-install-notes.md for manual steps"
