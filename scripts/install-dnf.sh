#!/usr/bin/env bash
source "$(dirname "$0")/utils.sh"

log_section "DNF Package Installation"

MANIFEST="$MANIFESTS_DIR/dnf-packages.txt"
COPR_MANIFEST="$MANIFESTS_DIR/copr-repos.txt"
REPOS_MANIFEST="$MANIFESTS_DIR/dnf-repos.txt"

# Enable COPR repos
if [[ -f "$COPR_MANIFEST" ]] && [[ -s "$COPR_MANIFEST" ]]; then
    log_info "Enabling COPR repositories..."
    while IFS= read -r copr_repo; do
        [[ -z "$copr_repo" || "$copr_repo" == \#* ]] && continue
        if dnf copr list --enabled 2>/dev/null | grep -q "$copr_repo"; then
            log_info "COPR already enabled: $copr_repo"
        else
            retry 2 sudo dnf copr enable -y "$copr_repo" || track_failure "copr" "Failed to enable: $copr_repo"
        fi
    done < "$COPR_MANIFEST"
fi

# RPM Fusion
if [[ -f "$REPOS_MANIFEST" ]] && grep -q "rpmfusion" "$REPOS_MANIFEST" 2>/dev/null; then
    fedora_version=$(rpm -E %fedora)
    if ! rpm -q rpmfusion-free-release &>/dev/null; then
        log_info "Installing RPM Fusion (free)..."
        retry 3 sudo dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_version}.noarch.rpm" || \
            track_failure "rpmfusion" "Failed to install RPM Fusion free"
    fi
    if ! rpm -q rpmfusion-nonfree-release &>/dev/null; then
        log_info "Installing RPM Fusion (nonfree)..."
        retry 3 sudo dnf install -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_version}.noarch.rpm" || \
            track_failure "rpmfusion" "Failed to install RPM Fusion nonfree"
    fi
fi

# Install packages
if [[ ! -f "$MANIFEST" ]]; then
    log_error "Manifest not found: $MANIFEST — run './forge.sh discover' first."
    exit 1
fi

total=$(grep -cv '^\s*$\|^\s*#' "$MANIFEST" || echo 0)
installed=0; skipped=0; failed=0

log_info "Processing $total packages..."
while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    pkg=$(echo "$pkg" | xargs)
    if is_pkg_installed "$pkg"; then skipped=$((skipped + 1)); continue; fi
    if retry 2 sudo dnf install -y "$pkg" &>/dev/null; then
        installed=$((installed + 1)); log_ok "Installed: $pkg"
    else
        failed=$((failed + 1)); track_failure "dnf" "Failed to install: $pkg"
    fi
done < "$MANIFEST"

log_info "Summary: $installed installed, $skipped already present, $failed failed"
summarize_failures
