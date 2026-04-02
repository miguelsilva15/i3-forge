#!/usr/bin/env bash
source "$(dirname "$0")/utils.sh"

log_section "Linking Dotfiles"

BACKUP_DIR="$HOME/.i3-forge/backups/$(date +%Y%m%d_%H%M%S)"

link_item() {
    local src="$1" dest="$2"

    # Already correct
    if [[ -L "$dest" ]] && [[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        log_info "Already linked: ${dest/#$HOME/\~}"
        return 0
    fi

    # Backup existing
    if [[ -e "$dest" ]] || [[ -L "$dest" ]]; then
        mkdir -p "$BACKUP_DIR"
        local backup_path="$BACKUP_DIR/${dest/#$HOME\//}"
        mkdir -p "$(dirname "$backup_path")"
        mv "$dest" "$backup_path"
        log_warn "Backed up: ${dest/#$HOME/\~}"
    fi

    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
    log_ok "Linked: ${dest/#$HOME/\~} → ${src/#$REPO_DIR/repo}"
}

find "$DOTFILES_DIR" -type f | while IFS= read -r src_file; do
    rel_path="${src_file#"$DOTFILES_DIR"/}"
    link_item "$src_file" "$HOME/$rel_path" || track_failure "link" "Failed: $rel_path"
done

[[ -d "$BACKUP_DIR" ]] && log_info "Backups in: $BACKUP_DIR"
summarize_failures
