#!/usr/bin/env bash
# discover.sh — audit the current system and populate manifests + dotfiles
# Usage:
#   ./scripts/discover.sh                    # discover everything
#   ./scripts/discover.sh --only dotfiles    # only discover dotfiles
#   ./scripts/discover.sh --only dnf         # only discover dnf packages
#   ./scripts/discover.sh --only flatpak
#   ./scripts/discover.sh --only source
#   ./scripts/discover.sh --only sysinfo

source "$(dirname "$0")/utils.sh"

# ── Parse --only flag ────────────────────────────────────────────────────────
ONLY=""
if [[ "${1:-}" == "--only" ]]; then
    ONLY="${2:-}"
elif [[ -n "${1:-}" ]]; then
    ONLY="$1"
fi

should_run() {
    if [[ -z "$ONLY" ]]; then
        return 0
    fi
    if [[ "$ONLY" == "$1" ]]; then
        return 0
    fi
    return 1
}

log_section "i3-forge Discovery"
if [[ -n "$ONLY" ]]; then
    log_info "Running only: $ONLY"
else
    log_info "Scanning your system to capture current setup..."
fi

> "$FAILED_LOG"

# ══════════════════════════════════════════════════════════════════════════════
# 1. DNF PACKAGES
# ══════════════════════════════════════════════════════════════════════════════
if should_run "dnf"; then

    log_section "DNF Packages"
    mkdir -p "$MANIFESTS_DIR"

    log_info "Fetching user-installed dnf packages..."
    if dnf repoquery --userinstalled 2>/dev/null | sed 's/-[0-9].*$//' | sort -u > "$MANIFESTS_DIR/dnf-packages.txt"; then
        count=$(wc -l < "$MANIFESTS_DIR/dnf-packages.txt")
        log_ok "Captured $count user-installed packages → manifests/dnf-packages.txt"
    else
        log_warn "dnf repoquery --userinstalled failed, trying fallback..."
        dnf history userinstalled 2>/dev/null | tail -n +2 | awk '{print $1}' | sort -u > "$MANIFESTS_DIR/dnf-packages.txt" || \
            track_failure "dnf" "Could not list user-installed packages"
    fi

    log_info "Capturing enabled repositories..."
    dnf repolist --enabled 2>/dev/null | tail -n +2 | awk '{print $1}' | sort > "$MANIFESTS_DIR/dnf-repos.txt" || \
        track_failure "dnf-repos" "Could not list enabled repos"

    if command_exists dnf; then
        log_info "Checking for COPR repositories..."
        find /etc/yum.repos.d/ -name "_copr_*" -exec basename {} .repo \; 2>/dev/null | \
            sed 's/^_copr_//' | sort > "$MANIFESTS_DIR/copr-repos.txt"
        copr_count=$(wc -l < "$MANIFESTS_DIR/copr-repos.txt")
        if [[ "$copr_count" -gt 0 ]]; then
            log_ok "Found $copr_count COPR repo(s)"
        else
            rm -f "$MANIFESTS_DIR/copr-repos.txt"
            log_info "No COPR repos found"
        fi
    fi

fi

# ══════════════════════════════════════════════════════════════════════════════
# 2. FLATPAK APPS
# ══════════════════════════════════════════════════════════════════════════════
if should_run "flatpak"; then

    log_section "Flatpak Apps"
    mkdir -p "$MANIFESTS_DIR"

    if command_exists flatpak; then
        log_info "Fetching installed Flatpak apps..."
        flatpak list --app --columns=application,origin 2>/dev/null | sort > "$MANIFESTS_DIR/flatpak-apps.txt"
        count=$(wc -l < "$MANIFESTS_DIR/flatpak-apps.txt")
        log_ok "Captured $count Flatpak apps → manifests/flatpak-apps.txt"

        flatpak remotes --columns=name,url 2>/dev/null > "$MANIFESTS_DIR/flatpak-remotes.txt"
        log_ok "Captured Flatpak remotes → manifests/flatpak-remotes.txt"
    else
        log_warn "Flatpak not installed, skipping"
    fi

fi

# ══════════════════════════════════════════════════════════════════════════════
# 3. SOURCE-BUILT / MANUAL BINARIES
# ══════════════════════════════════════════════════════════════════════════════
if should_run "source"; then

    log_section "Source-built / Manual Binaries"
    mkdir -p "$MANIFESTS_DIR"

    log_info "Scanning for binaries in /usr/local/bin and ~/.local/bin..."

    SOURCE_BUILDS_FILE="$MANIFESTS_DIR/source-builds.yml"

    cat > "$SOURCE_BUILDS_FILE" << 'HEADER'
# source-builds.yml — tools built from source
# Fill in git_url and build_commands for each entry.
#
# Example:
# - name: picom
#   git_url: https://github.com/yshui/picom.git
#   build_commands:
#     - meson setup --buildtype=release build
#     - ninja -C build
#     - sudo ninja -C build install
#   binary_check: picom --version
#   dependencies:
#     - meson
#     - ninja-build

builds:
HEADER

    local_bins=()

    for dir in /usr/local/bin "$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/go/bin"; do
        if [[ -d "$dir" ]]; then
            while IFS= read -r bin; do
                bin_name=$(basename "$bin")
                if ! rpm -qf "$bin" &>/dev/null; then
                    local_bins+=("$bin_name ($dir)")
                    echo "  - name: $bin_name" >> "$SOURCE_BUILDS_FILE"
                    echo "    location: $dir" >> "$SOURCE_BUILDS_FILE"
                    echo "    git_url: \"\"  # TODO: fill in" >> "$SOURCE_BUILDS_FILE"
                    echo "    build_commands: []  # TODO: fill in" >> "$SOURCE_BUILDS_FILE"
                    echo "    binary_check: \"$bin_name --version\"" >> "$SOURCE_BUILDS_FILE"
                    echo "    dependencies: []  # TODO: fill in" >> "$SOURCE_BUILDS_FILE"
                    echo "" >> "$SOURCE_BUILDS_FILE"
                fi
            done < <(find "$dir" -maxdepth 1 -type f -executable 2>/dev/null)
        fi
    done

    if [[ ${#local_bins[@]} -gt 0 ]]; then
        log_ok "Found ${#local_bins[@]} non-rpm binaries:"
        for b in "${local_bins[@]}"; do echo "         → $b"; done
        log_warn "Fill in git_url and build_commands in manifests/source-builds.yml"
    else
        log_info "No source-built binaries detected"
    fi

    if [[ -f "$HOME/.cargo/.crates.toml" ]]; then
        log_info "Detected Cargo-installed crates..."
        grep -oP 'name = "\K[^"]+' "$HOME/.cargo/.crates.toml" 2>/dev/null | sort -u > "$MANIFESTS_DIR/cargo-packages.txt"
        log_ok "Captured Cargo packages → manifests/cargo-packages.txt"
    fi

fi

# ══════════════════════════════════════════════════════════════════════════════
# 4. DOTFILES
# ══════════════════════════════════════════════════════════════════════════════
if should_run "dotfiles"; then

    log_section "Dotfiles"
    log_info "Scanning for configuration files..."

    # Clean previous dotfiles to avoid duplication
    rm -rf "$DOTFILES_DIR"
    mkdir -p "$DOTFILES_DIR/.config"

    # Check for .forgeignore
    FORGEIGNORE="$REPO_DIR/.forgeignore"
    declare -a IGNORE_PATTERNS=()
    if [[ -f "$FORGEIGNORE" ]]; then
        while IFS= read -r pattern; do
            [[ -z "$pattern" || "$pattern" == \#* ]] && continue
            IGNORE_PATTERNS+=("$pattern")
        done < "$FORGEIGNORE"
        log_info "Loaded ${#IGNORE_PATTERNS[@]} ignore patterns from .forgeignore"
    fi

    should_ignore() {
        local path="$1"
        for pattern in "${IGNORE_PATTERNS[@]}"; do
            # shellcheck disable=SC2254
            if [[ "$path" == $pattern ]]; then
                return 0
            fi
        done
        return 1
    }

    copy_config() {
        local src="$1"
        local rel_path="$2"
        local dest="$DOTFILES_DIR/$rel_path"

        if should_ignore "$rel_path"; then
            log_info "Ignoring (forgeignore): $rel_path"
            return
        fi

        mkdir -p "$(dirname "$dest")"

        if [[ -d "$src" ]]; then
            rm -rf "$dest"
            cp -r "$src" "$dest"
        else
            cp "$src" "$dest"
        fi
        log_ok "Captured: $rel_path"
    }

    # ── .config directories ──────────────────────────────────────────────────
    for dir in i3 i3status i3blocks polybar kitty alacritty foot wezterm \
               rofi dunst betterlockscreen conky Thunar copyq volumeicon \
               xfce4 gtk-3.0 gtk-4.0 fontconfig fish/functions fish/completions; do
        [[ -d "$HOME/.config/$dir" ]] && copy_config "$HOME/.config/$dir" ".config/$dir"
    done

    # ── .config files (not directories) ──────────────────────────────────────
    for f in picom.conf starship.toml mimeapps.list user-dirs.dirs; do
        [[ -f "$HOME/.config/$f" ]] && copy_config "$HOME/.config/$f" ".config/$f"
    done

    # ── Home directory dotfiles ──────────────────────────────────────────────
    for f in .bashrc .bash_profile .bash_aliases .bash_logout .profile \
             .zshrc .zshenv .zsh_aliases .zprofile .zcompdump \
             .vimrc .tmux.conf .gitconfig .gitignore_global \
             .gtkrc-2.0 .fehbg \
             .Xresources .Xdefaults .xinitrc .xprofile .Xmodmap; do
        [[ -f "$HOME/$f" ]] && copy_config "$HOME/$f" "$f"
    done

    # ── Home directory dotfile directories ───────────────────────────────────
    [[ -d "$HOME/.vim" ]] && copy_config "$HOME/.vim" ".vim"
    [[ -d "$HOME/.icons" ]] && copy_config "$HOME/.icons" ".icons"
    [[ -d "$HOME/.themes" ]] && copy_config "$HOME/.themes" ".themes"

    # ── Tmux ─────────────────────────────────────────────────────────────────
    [[ -d "$HOME/.config/tmux" ]] && copy_config "$HOME/.config/tmux" ".config/tmux"

    # ── Nvim ─────────────────────────────────────────────────────────────────
    [[ -d "$HOME/.config/nvim" ]] && copy_config "$HOME/.config/nvim" ".config/nvim"

    # ── VS Code (skip — too large, use settings sync) ────────────────────────
    [[ -d "$HOME/.config/Code" ]] && log_warn "Skipping .config/Code (use VS Code Settings Sync instead)"

    # ── Summary ──────────────────────────────────────────────────────────────
    echo ""
    echo "  Dotfiles captured:"
    find "$DOTFILES_DIR" -type f | sort | while read -r f; do
        echo "    → ${f#"$DOTFILES_DIR"/}"
    done
    echo ""

fi

# ══════════════════════════════════════════════════════════════════════════════
# 5. SYSTEM INFO
# ══════════════════════════════════════════════════════════════════════════════
if should_run "sysinfo"; then

    log_section "System Info Snapshot"
    mkdir -p "$MANIFESTS_DIR"

    SYSINFO="$MANIFESTS_DIR/system-info.txt"
    {
        echo "=== Fedora Version ==="
        cat /etc/fedora-release 2>/dev/null || echo "Not Fedora"
        echo ""
        echo "=== Kernel ==="
        uname -r
        echo ""
        echo "=== Display Server ==="
        echo "${XDG_SESSION_TYPE:-unknown}"
        echo ""
        echo "=== Shell ==="
        echo "$SHELL"
        echo ""
        echo "=== i3 Version ==="
        i3 --version 2>/dev/null || echo "i3 not found"
        echo ""
        echo "=== Screen Resolution ==="
        xrandr --current 2>/dev/null | grep -E '^\S+ connected' || echo "xrandr unavailable"
        echo ""
        echo "=== Date ==="
        date
    } > "$SYSINFO"

    log_ok "System info saved → manifests/system-info.txt"

fi

# ══════════════════════════════════════════════════════════════════════════════
# Final Summary
# ══════════════════════════════════════════════════════════════════════════════
log_section "Discovery Complete"

echo "  Manifests:"
for f in "$MANIFESTS_DIR"/*; do
    [[ -f "$f" ]] && echo "    → $(basename "$f")  ($(wc -l < "$f") lines)"
done
echo ""

summarize_failures

if [[ -z "$ONLY" ]]; then
    log_info "Next steps:"
    echo "  1. Review manifests/ — remove packages you don't want"
    echo "  2. Fill in manifests/source-builds.yml with git URLs and build steps"
    echo "  3. Check dotfiles/ — remove anything sensitive (tokens, keys)"
    echo "  4. Commit: git add -A && git commit -m 'Initial discovery'"
    echo ""
fi
