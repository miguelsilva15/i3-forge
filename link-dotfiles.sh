#!/usr/bin/env bash
# link-dotfiles.sh — symlink dotfiles from repo into $HOME
# Idempotent: skips already-correct symlinks, backs up conflicting files.

source "$(dirname "$0")/utils.sh"

log_section "Linking Dotfiles"

BACKUP_DIR="$HOME/.i3-forge/backups/$(date +%Y%m%d_%H%M%S)"

link_item() {
    local src="$1"   # absolute path in repo
    local dest="$2"  # absolute path in $HOME

    # Already a correct symlink
    if [[ -L "$dest" ]] && [[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        log_info "Already linked: ${dest/#$HOME/\~}"
        return 0
    fi

    # Something exists at the destination — back it up
    if [[ -e "$dest" ]] || [[ -L "$dest" ]]; then
        mkdir -p "$BACKUP_DIR"
        local backup_path="$BACKUP_DIR/${dest/#$HOME\//}"
        mkdir -p "$(dirname "$backup_path")"
        mv "$dest" "$backup_path"
        log_warn "Backed up existing: ${dest/#$HOME/\~} → ${backup_path/#$HOME/\~}"
    fi

    # Create parent directory if needed
    mkdir -p "$(dirname "$dest")"

    # Create symlink
    ln -s "$src" "$dest"
    log_ok "Linked: ${dest/#$HOME/\~} → ${src/#$REPO_DIR/repo}"
}

# Walk the dotfiles directory and create symlinks for each file
find "$DOTFILES_DIR" -type f | while IFS= read -r src_file; do
    # Get the relative path within dotfiles/
    rel_path="${src_file#"$DOTFILES_DIR"/}"
    dest_path="$HOME/$rel_path"
    link_item "$src_file" "$dest_path" || track_failure "link" "Failed to link $rel_path"
done

echo ""
if [[ -d "$BACKUP_DIR" ]]; then
    log_info "Backups saved to: $BACKUP_DIR"
fi

summarize_failures
