#!/usr/bin/env bash
# install-flatpak.sh — install Flatpak apps from manifest

source "$(dirname "$0")/utils.sh"

log_section "Flatpak Installation"

MANIFEST="$MANIFESTS_DIR/flatpak-apps.txt"
REMOTES_MANIFEST="$MANIFESTS_DIR/flatpak-remotes.txt"

# ── Ensure flatpak is installed ──────────────────────────────────────────────
if ! command_exists flatpak; then
    log_info "Installing Flatpak..."
    if retry 3 sudo dnf install -y flatpak; then
        log_ok "Flatpak installed"
    else
        track_failure "flatpak" "Could not install flatpak itself"
        summarize_failures
        exit 1
    fi
fi

# ── Add remotes ──────────────────────────────────────────────────────────────
if [[ -f "$REMOTES_MANIFEST" ]] && [[ -s "$REMOTES_MANIFEST" ]]; then
    log_info "Configuring Flatpak remotes..."
    while IFS=$'\t' read -r name url; do
        [[ -z "$name" || "$name" == \#* ]] && continue
        if flatpak remotes --columns=name | grep -q "^${name}$"; then
            log_info "Remote already configured: $name"
        else
            if retry 2 flatpak remote-add --if-not-exists "$name" "$url"; then
                log_ok "Added remote: $name ($url)"
            else
                track_failure "flatpak-remote" "Failed to add remote: $name"
            fi
        fi
    done < "$REMOTES_MANIFEST"
else
    # At minimum, ensure Flathub is available
    if ! flatpak remotes --columns=name | grep -q "^flathub$"; then
        log_info "Adding Flathub remote..."
        retry 3 flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || \
            track_failure "flatpak-remote" "Failed to add Flathub"
    fi
fi

# ── Install apps ─────────────────────────────────────────────────────────────
if [[ ! -f "$MANIFEST" ]]; then
    log_error "Manifest not found: $MANIFEST"
    log_info "Run './forge.sh discover' first to generate it."
    exit 1
fi

installed=0
skipped=0
failed=0

while IFS=$'\t' read -r app_id origin; do
    [[ -z "$app_id" || "$app_id" == \#* ]] && continue
    app_id=$(echo "$app_id" | xargs)
    origin=$(echo "${origin:-flathub}" | xargs)

    if is_flatpak_installed "$app_id"; then
        skipped=$((skipped + 1))
        continue
    fi

    if retry 2 flatpak install -y "$origin" "$app_id"; then
        installed=$((installed + 1))
        log_ok "Installed: $app_id"
    else
        failed=$((failed + 1))
        track_failure "flatpak" "Failed to install: $app_id from $origin"
    fi
done < "$MANIFEST"

echo ""
log_info "Summary: $installed installed, $skipped already present, $failed failed"

summarize_failures
