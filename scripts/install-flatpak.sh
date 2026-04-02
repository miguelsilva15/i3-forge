#!/usr/bin/env bash
source "$(dirname "$0")/utils.sh"

log_section "Flatpak Installation"

MANIFEST="$MANIFESTS_DIR/flatpak-apps.txt"
REMOTES_MANIFEST="$MANIFESTS_DIR/flatpak-remotes.txt"

if ! command_exists flatpak; then
    log_info "Installing Flatpak..."
    retry 3 sudo dnf install -y flatpak || { track_failure "flatpak" "Could not install flatpak"; summarize_failures; exit 1; }
fi

# Add remotes
if [[ -f "$REMOTES_MANIFEST" ]] && [[ -s "$REMOTES_MANIFEST" ]]; then
    while IFS=$'\t' read -r name url; do
        [[ -z "$name" || "$name" == \#* ]] && continue
        flatpak remotes --columns=name | grep -q "^${name}$" || \
            retry 2 flatpak remote-add --if-not-exists "$name" "$url" || track_failure "flatpak-remote" "Failed: $name"
    done < "$REMOTES_MANIFEST"
else
    flatpak remotes --columns=name | grep -q "^flathub$" || \
        retry 3 flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

if [[ ! -f "$MANIFEST" ]]; then
    log_error "Manifest not found: $MANIFEST — run './forge.sh discover' first."
    exit 1
fi

installed=0; skipped=0; failed=0
while IFS=$'\t' read -r app_id origin; do
    [[ -z "$app_id" || "$app_id" == \#* ]] && continue
    app_id=$(echo "$app_id" | xargs); origin=$(echo "${origin:-flathub}" | xargs)
    if is_flatpak_installed "$app_id"; then skipped=$((skipped + 1)); continue; fi
    if retry 2 flatpak install -y "$origin" "$app_id"; then
        installed=$((installed + 1)); log_ok "Installed: $app_id"
    else
        failed=$((failed + 1)); track_failure "flatpak" "Failed: $app_id"
    fi
done < "$MANIFEST"

log_info "Summary: $installed installed, $skipped already present, $failed failed"
summarize_failures
