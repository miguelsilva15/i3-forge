#!/usr/bin/env bash
# bootstrap-i3-forge.sh
# Run this ONCE to create the full i3-forge repo structure.
# Usage: bash bootstrap-i3-forge.sh [target-dir]
#   default target-dir: ~/i3-forge

set -euo pipefail

TARGET="${1:-$HOME/i3-forge}"

echo "Creating i3-forge in: $TARGET"
mkdir -p "$TARGET"/{scripts,manifests,dotfiles/.config,docs}

# ══════════════════════════════════════════════════════════════════════════════
# CLAUDE.md
# ══════════════════════════════════════════════════════════════════════════════
cat > "$TARGET/CLAUDE.md" << 'ENDOFFILE'
# i3-forge

## What This Is

A reproducible provisioning system for an i3wm Fedora workstation.
It captures installed packages, Flatpaks, source-built tools, and all dotfile
configurations — then replays them on a fresh Fedora install.

## Repo Layout

```
i3-forge/
├── CLAUDE.md              # You are here — project brain
├── README.md              # Human-readable setup guide
├── forge.sh               # Main entrypoint: runs discovery OR restore
├── scripts/
│   ├── discover.sh        # Audit current system, populate package lists & dotfiles
│   ├── restore.sh         # Idempotent restore: packages → flatpaks → dotfiles → source builds
│   ├── link-dotfiles.sh   # Symlink dotfiles into $HOME
│   ├── install-dnf.sh     # Install dnf packages from manifest
│   ├── install-flatpak.sh # Install Flatpak apps from manifest
│   ├── install-source.sh  # Build/install source-built tools from recipes
│   └── utils.sh           # Shared logging, error handling, retry logic
├── dotfiles/              # Mirror of $HOME config tree (symlinked into place)
├── manifests/
│   ├── dnf-packages.txt       # One package per line
│   ├── flatpak-apps.txt       # One app-id per line
│   └── source-builds.yml      # Name, repo URL, build steps
└── docs/
    └── post-install-notes.md  # Manual steps that can't be automated
```

## Key Principles

- **Idempotent**: Every script can be re-run safely. It skips what's already done.
- **Fail-resistant**: Errors in one step don't abort the whole process.
  Failures are logged to `~/.i3-forge/restore.log` and summarized at the end.
- **Symlinks, not copies**: Dotfiles live in this repo and are symlinked into $HOME.
  Edit in either place and changes propagate.
- **Manifests are plain text**: Easy to diff, review, and edit by hand.

## Commands

```bash
# First time: discover your current setup
./forge.sh discover

# On a fresh machine: restore everything
./forge.sh restore

# Just re-link dotfiles (after editing)
./forge.sh link

# Restore only a specific layer
./forge.sh restore --only dnf
./forge.sh restore --only flatpak
./forge.sh restore --only source
./forge.sh restore --only dotfiles
```

## For Claude Code

When working on this repo:

1. **Never hardcode paths** — use `$HOME`, `$REPO_DIR`, `$XDG_CONFIG_HOME`.
2. **All scripts must be POSIX-friendly bash** (bash 5+, no zsh-isms).
3. **Every script sources `scripts/utils.sh`** for logging and error handling.
4. **Test idempotency**: running any script twice must produce the same result.
5. **Don't auto-commit**: the user decides when to commit.
6. **Source build recipes** go in `manifests/source-builds.yml` — each entry
   needs: name, git_url, build_commands (list), binary_check (how to verify).
7. **Dotfile discovery** should detect which configs actually exist, not assume.
8. **Respect `.forgeignore`** if present — glob patterns for dotfiles to skip.
ENDOFFILE

# ══════════════════════════════════════════════════════════════════════════════
# README.md
# ══════════════════════════════════════════════════════════════════════════════
cat > "$TARGET/README.md" << 'ENDOFFILE'
# i3-forge

Reproducible provisioning for an i3wm Fedora workstation. Capture your setup once, restore it anywhere.

## Quick Start

### Capture your current setup

```bash
cd ~/i3-forge
./forge.sh discover
```

This scans your system and populates:
- `manifests/dnf-packages.txt` — all user-installed dnf packages
- `manifests/flatpak-apps.txt` — Flatpak applications
- `manifests/source-builds.yml` — binaries built from source (needs manual edits)
- `dotfiles/` — your i3, shell, terminal, and other configs

**After discovery, review and clean up:**
1. Remove packages you don't need from `manifests/dnf-packages.txt`
2. Fill in `git_url` and `build_commands` in `manifests/source-builds.yml`
3. Check `dotfiles/` for anything sensitive (API keys, tokens) — add patterns to `.forgeignore`
4. Commit and push

### Restore on a fresh Fedora install

```bash
sudo dnf install -y git
git clone <your-repo-url> ~/i3-forge
cd ~/i3-forge
./forge.sh restore
```

The restore runs in order: **dnf repos → dnf packages → Flatpak → source builds → dotfiles**

Each step is idempotent (safe to re-run) and failure-resistant (one failed package won't stop the rest).

### Selective restore

```bash
./forge.sh restore --only dnf       # Just packages
./forge.sh restore --only flatpak   # Just Flatpak apps
./forge.sh restore --only source    # Just source builds
./forge.sh restore --only dotfiles  # Just symlink configs
./forge.sh link                     # Shortcut for dotfiles only
```

## How Dotfiles Work

Dotfiles are **symlinked**, not copied. The repo is the source of truth:

```
~/.config/i3/config  →  ~/i3-forge/dotfiles/.config/i3/config
~/.bashrc            →  ~/i3-forge/dotfiles/.bashrc
```

Edit in either location — changes are the same file. Existing files are backed up to `~/.i3-forge/backups/` before linking.

## .forgeignore

Create a `.forgeignore` file in the repo root to skip dotfiles during discovery:

```
.config/chromium*
.config/google-chrome*
.ssh/*
.gnupg/*
```

## Logs

All operations log to `~/.i3-forge/restore.log`. Failures are collected in `~/.i3-forge/failures.log` and summarized at the end of each run.
ENDOFFILE

# ══════════════════════════════════════════════════════════════════════════════
# .gitignore
# ══════════════════════════════════════════════════════════════════════════════
cat > "$TARGET/.gitignore" << 'ENDOFFILE'
*.pem
*.key
id_rsa*
id_ed25519*
*.log
.DS_Store
Thumbs.db
*.swp
*.swo
*~
ENDOFFILE

# ══════════════════════════════════════════════════════════════════════════════
# .forgeignore
# ══════════════════════════════════════════════════════════════════════════════
cat > "$TARGET/.forgeignore" << 'ENDOFFILE'
# .forgeignore — patterns for dotfiles to skip during discovery

# Secrets and credentials
.ssh/*
.gnupg/*
.aws/*
.config/gh/hosts.yml

# Browser data (too large, synced via browser account)
.config/chromium*
.config/google-chrome*
.mozilla/*

# Caches and state
.config/*/Cache*
.config/*/cache*
.config/*/GPUCache*
.local/*
.cache/*

# Desktop environment state
.config/dconf/*
.config/pulse/*
.config/pipewire/*
ENDOFFILE

# ══════════════════════════════════════════════════════════════════════════════
# docs/post-install-notes.md
# ══════════════════════════════════════════════════════════════════════════════
cat > "$TARGET/docs/post-install-notes.md" << 'ENDOFFILE'
# Post-Install Notes

Things that can't be fully automated. Do these after running `./forge.sh restore`.

## Manual Steps

- [ ] **SSH keys**: Copy from backup or generate new ones (`ssh-keygen -t ed25519`)
- [ ] **GPG keys**: Import from backup (`gpg --import private.key`)
- [ ] **Git credentials**: Set up `git config --global user.name` / `user.email`
- [ ] **Browser login**: Sign into Firefox/Chrome to sync bookmarks, extensions, passwords
- [ ] **Flatpak permissions**: Some Flatpak apps may need Flatseal adjustments
- [ ] **Display setup**: Run `xrandr` or `arandr` to configure multi-monitor layout
- [ ] **Wallpaper**: Set wallpaper with `feh --bg-scale /path/to/wallpaper.jpg`
- [ ] **Fonts**: Copy custom fonts to `~/.local/share/fonts/` and run `fc-cache -fv`

## Known Quirks

<!-- Add notes about things that broke or needed tweaking -->
ENDOFFILE

# ══════════════════════════════════════════════════════════════════════════════
# scripts/utils.sh
# ══════════════════════════════════════════════════════════════════════════════
cat > "$TARGET/scripts/utils.sh" << 'ENDOFFILE'
#!/usr/bin/env bash
# utils.sh — shared logging, error handling, and retry logic for i3-forge

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFESTS_DIR="$REPO_DIR/manifests"
DOTFILES_DIR="$REPO_DIR/dotfiles"
SCRIPTS_DIR="$REPO_DIR/scripts"
LOG_DIR="$HOME/.i3-forge"
LOG_FILE="$LOG_DIR/restore.log"
FAILED_LOG="$LOG_DIR/failures.log"

mkdir -p "$LOG_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

_timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

log_info()    { echo -e "${BLUE}[INFO]${NC}  $(_timestamp) $*" | tee -a "$LOG_FILE"; }
log_ok()      { echo -e "${GREEN}[  OK]${NC}  $(_timestamp) $*" | tee -a "$LOG_FILE"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $(_timestamp) $*" | tee -a "$LOG_FILE"; }
log_error()   { echo -e "${RED}[FAIL]${NC}  $(_timestamp) $*" | tee -a "$LOG_FILE"; }
log_section() { echo -e "\n${BOLD}${CYAN}══════ $* ══════${NC}\n" | tee -a "$LOG_FILE"; }

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

retry() {
    local max_attempts="$1"
    shift
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if "$@"; then return 0; fi
        log_warn "Attempt $attempt/$max_attempts failed: $*"
        attempt=$((attempt + 1))
        sleep 2
    done
    return 1
}

is_pkg_installed()    { rpm -q "$1" &>/dev/null; }
is_flatpak_installed() { flatpak list --app --columns=application 2>/dev/null | grep -q "^${1}$"; }
command_exists()      { command -v "$1" &>/dev/null; }

confirm() {
    local prompt="${1:-Continue?}"
    echo -en "${YELLOW}${prompt} [y/N] ${NC}"
    read -r reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

_cleanup() { echo -en "$NC"; }
trap _cleanup EXIT
ENDOFFILE

# ══════════════════════════════════════════════════════════════════════════════
# scripts/discover.sh
# ══════════════════════════════════════════════════════════════════════════════
cat > "$TARGET/scripts/discover.sh" << 'ENDOFFILE'
#!/usr/bin/env bash
# discover.sh — audit the current system and populate manifests + dotfiles

source "$(dirname "$0")/utils.sh"

log_section "i3-forge Discovery"
log_info "Scanning your system to capture current setup..."
> "$FAILED_LOG"

# ── 1. DNF PACKAGES ─────────────────────────────────────────────────────────
log_section "DNF Packages"
mkdir -p "$MANIFESTS_DIR"

log_info "Fetching user-installed dnf packages..."
if dnf repoquery --userinstalled --qf '%{name}' 2>/dev/null | sort -u > "$MANIFESTS_DIR/dnf-packages.txt"; then
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

# ── 2. FLATPAK APPS ─────────────────────────────────────────────────────────
log_section "Flatpak Apps"
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

# ── 3. SOURCE-BUILT BINARIES ────────────────────────────────────────────────
log_section "Source-built / Manual Binaries"
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
                cat >> "$SOURCE_BUILDS_FILE" << EOF
  - name: $bin_name
    location: $dir
    git_url: ""  # TODO: fill in
    build_commands: []  # TODO: fill in
    binary_check: "$bin_name --version"
    dependencies: []  # TODO: fill in

EOF
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

# ── 4. DOTFILES ──────────────────────────────────────────────────────────────
log_section "Dotfiles"
log_info "Scanning for configuration files..."

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
        if [[ "$path" == $pattern ]]; then return 0; fi
    done
    return 1
}

copy_config() {
    local src="$1" rel_path="$2"
    local dest="$DOTFILES_DIR/$rel_path"
    if should_ignore "$rel_path"; then
        log_info "Ignoring (forgeignore): $rel_path"
        return
    fi
    mkdir -p "$(dirname "$dest")"
    if [[ -d "$src" ]]; then cp -r "$src" "$dest"; else cp "$src" "$dest"; fi
    log_ok "Captured: $rel_path"
}

# i3
for dir in "$HOME/.config/i3" "$HOME/.i3"; do
    [[ -d "$dir" ]] && { copy_config "$dir" ".config/i3"; break; }
done

# i3status / i3blocks / polybar
for tool in i3status i3blocks polybar; do
    dir="$HOME/.config/$tool"
    [[ -d "$dir" ]] && copy_config "$dir" ".config/$tool"
done

# Terminal emulators
for term in alacritty kitty foot wezterm; do
    dir="$HOME/.config/$term"
    [[ -d "$dir" ]] && copy_config "$dir" ".config/$term"
done

# Compositor
for comp in picom compton; do
    dir="$HOME/.config/$comp"
    [[ -d "$dir" ]] && copy_config "$dir" ".config/$comp"
    [[ -f "$HOME/.$comp.conf" ]] && copy_config "$HOME/.$comp.conf" ".$comp.conf"
done

# Launcher
[[ -d "$HOME/.config/rofi" ]] && copy_config "$HOME/.config/rofi" ".config/rofi"

# Notifications
[[ -d "$HOME/.config/dunst" ]] && copy_config "$HOME/.config/dunst" ".config/dunst"

# Shell configs
for shellrc in .bashrc .bash_profile .bash_aliases .bash_logout .profile \
               .zshrc .zshenv .zsh_aliases .zprofile \
               .config/fish/config.fish; do
    [[ -f "$HOME/$shellrc" ]] && copy_config "$HOME/$shellrc" "$shellrc"
done
for fish_dir in "$HOME/.config/fish/functions" "$HOME/.config/fish/completions"; do
    [[ -d "$fish_dir" ]] && copy_config "$fish_dir" ".config/fish/$(basename "$fish_dir")"
done
[[ -f "$HOME/.config/starship.toml" ]] && copy_config "$HOME/.config/starship.toml" ".config/starship.toml"

# Editor
[[ -f "$HOME/.vimrc" ]] && copy_config "$HOME/.vimrc" ".vimrc"
[[ -d "$HOME/.vim" ]] && copy_config "$HOME/.vim" ".vim"
[[ -d "$HOME/.config/nvim" ]] && copy_config "$HOME/.config/nvim" ".config/nvim"

# Tmux
[[ -f "$HOME/.tmux.conf" ]] && copy_config "$HOME/.tmux.conf" ".tmux.conf"
[[ -d "$HOME/.config/tmux" ]] && copy_config "$HOME/.config/tmux" ".config/tmux"

# Git
[[ -f "$HOME/.gitconfig" ]] && copy_config "$HOME/.gitconfig" ".gitconfig"
[[ -f "$HOME/.gitignore_global" ]] && copy_config "$HOME/.gitignore_global" ".gitignore_global"

# X11
for xfile in .Xresources .Xdefaults .xinitrc .xprofile .Xmodmap; do
    [[ -f "$HOME/$xfile" ]] && copy_config "$HOME/$xfile" "$xfile"
done

# GTK theming
for gtk_dir in .config/gtk-3.0 .config/gtk-4.0; do
    [[ -d "$HOME/$gtk_dir" ]] && copy_config "$HOME/$gtk_dir" "$gtk_dir"
done
[[ -f "$HOME/.gtkrc-2.0" ]] && copy_config "$HOME/.gtkrc-2.0" ".gtkrc-2.0"

# Icons / themes
[[ -d "$HOME/.icons" ]] && copy_config "$HOME/.icons" ".icons"
[[ -d "$HOME/.themes" ]] && copy_config "$HOME/.themes" ".themes"

# Misc
for misc in .config/fontconfig .config/mimeapps.list .config/user-dirs.dirs; do
    [[ -e "$HOME/$misc" ]] && copy_config "$HOME/$misc" "$misc"
done

# ── 5. SYSTEM INFO ──────────────────────────────────────────────────────────
log_section "System Info Snapshot"
{
    echo "=== Fedora Version ==="; cat /etc/fedora-release 2>/dev/null || echo "Not Fedora"
    echo ""; echo "=== Kernel ==="; uname -r
    echo ""; echo "=== Display Server ==="; echo "${XDG_SESSION_TYPE:-unknown}"
    echo ""; echo "=== Shell ==="; echo "$SHELL"
    echo ""; echo "=== i3 Version ==="; i3 --version 2>/dev/null || echo "i3 not found"
    echo ""; echo "=== Screen Resolution ==="
    xrandr --current 2>/dev/null | grep -E '^\S+ connected' || echo "xrandr unavailable"
    echo ""; echo "=== Date ==="; date
} > "$MANIFESTS_DIR/system-info.txt"
log_ok "System info saved → manifests/system-info.txt"

# ── Summary ──────────────────────────────────────────────────────────────────
log_section "Discovery Complete"
echo "  Manifests:"
for f in "$MANIFESTS_DIR"/*; do echo "    → $(basename "$f")  ($(wc -l < "$f") lines)"; done
echo ""
echo "  Dotfiles captured:"
find "$DOTFILES_DIR" -type f 2>/dev/null | while read -r f; do echo "    → ${f#"$DOTFILES_DIR"/}"; done
echo ""
summarize_failures
log_info "Next steps:"
echo "  1. Review manifests/ — remove packages you don't want"
echo "  2. Fill in manifests/source-builds.yml with git URLs and build steps"
echo "  3. Check dotfiles/ — remove anything sensitive (tokens, keys)"
echo "  4. Commit: git add -A && git commit -m 'Initial discovery'"
ENDOFFILE

# ══════════════════════════════════════════════════════════════════════════════
# scripts/install-dnf.sh
# ══════════════════════════════════════════════════════════════════════════════
cat > "$TARGET/scripts/install-dnf.sh" << 'ENDOFFILE'
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
ENDOFFILE

# ══════════════════════════════════════════════════════════════════════════════
# scripts/install-flatpak.sh
# ══════════════════════════════════════════════════════════════════════════════
cat > "$TARGET/scripts/install-flatpak.sh" << 'ENDOFFILE'
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
ENDOFFILE

# ══════════════════════════════════════════════════════════════════════════════
# scripts/install-source.sh
# ══════════════════════════════════════════════════════════════════════════════
cat > "$TARGET/scripts/install-source.sh" << 'ENDOFFILE'
#!/usr/bin/env bash
source "$(dirname "$0")/utils.sh"

log_section "Source Build Installation"

MANIFEST="$MANIFESTS_DIR/source-builds.yml"
BUILD_DIR="$HOME/.i3-forge/builds"

if [[ ! -f "$MANIFEST" ]]; then
    log_error "Source build manifest not found — run './forge.sh discover' first."
    exit 1
fi
mkdir -p "$BUILD_DIR"

current_name="" current_git_url="" current_binary_check=""
declare -a current_build_cmds=() current_deps=()
in_build=false; in_deps=false

process_entry() {
    [[ -z "$current_name" || -z "$current_git_url" ]] && return
    [[ "$current_git_url" == '""' || "$current_git_url" == "\"\"" ]] && { log_warn "Skipping $current_name — no git_url"; return; }

    log_info "Processing: $current_name"

    if [[ -n "$current_binary_check" ]]; then
        local check_cmd="${current_binary_check//\"/}"
        eval "$check_cmd" &>/dev/null && { log_info "Already installed: $current_name"; return; }
    fi

    for dep in "${current_deps[@]}"; do
        dep="$(echo "${dep//\"/}" | xargs)"
        is_pkg_installed "$dep" || sudo dnf install -y "$dep" &>/dev/null || track_failure "source-dep" "Dep $dep for $current_name"
    done

    local repo_dir="$BUILD_DIR/$current_name" git_url="${current_git_url//\"/}"
    if [[ -d "$repo_dir/.git" ]]; then
        (cd "$repo_dir" && git pull --ff-only) || (rm -rf "$repo_dir" && git clone "$git_url" "$repo_dir")
    else
        rm -rf "$repo_dir"
        retry 2 git clone "$git_url" "$repo_dir" || { track_failure "source" "Clone failed: $git_url"; return; }
    fi

    (
        cd "$repo_dir" || exit 1
        for cmd in "${current_build_cmds[@]}"; do
            cmd="$(echo "${cmd//\"/}" | xargs)"; [[ -z "$cmd" ]] && continue
            log_info "  Running: $cmd"
            eval "$cmd" || { track_failure "source" "Build failed for $current_name: $cmd"; exit 1; }
        done
    ) || return

    if [[ -n "$current_binary_check" ]]; then
        local check_cmd="${current_binary_check//\"/}"
        eval "$check_cmd" &>/dev/null && log_ok "Built: $current_name" || track_failure "source" "Verify failed: $current_name"
    else
        log_ok "Built: $current_name (no verify)"
    fi
}

while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.*) ]]; then
        process_entry
        current_name="$(echo "${BASH_REMATCH[1]//\"/}" | xargs)"
        current_git_url="" current_binary_check="" current_build_cmds=() current_deps=()
        in_build=false; in_deps=false; continue
    fi
    [[ "$line" =~ ^[[:space:]]*git_url:[[:space:]]*(.*) ]] && { current_git_url="${BASH_REMATCH[1]}"; in_build=false; in_deps=false; continue; }
    [[ "$line" =~ ^[[:space:]]*binary_check:[[:space:]]*(.*) ]] && { current_binary_check="${BASH_REMATCH[1]}"; in_build=false; in_deps=false; continue; }
    [[ "$line" =~ ^[[:space:]]*build_commands: ]] && { in_build=true; in_deps=false; continue; }
    [[ "$line" =~ ^[[:space:]]*dependencies: ]] && { in_deps=true; in_build=false; continue; }
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+(.*) ]]; then
        $in_build && current_build_cmds+=("${BASH_REMATCH[1]}")
        $in_deps && current_deps+=("${BASH_REMATCH[1]}")
    fi
done < "$MANIFEST"
process_entry

# Cargo packages
CARGO_MANIFEST="$MANIFESTS_DIR/cargo-packages.txt"
if [[ -f "$CARGO_MANIFEST" ]] && [[ -s "$CARGO_MANIFEST" ]]; then
    log_section "Cargo Packages"
    if command_exists cargo; then
        while IFS= read -r crate; do
            [[ -z "$crate" || "$crate" == \#* ]] && continue
            crate="$(echo "$crate" | xargs)"
            command_exists "$crate" && { log_info "Already: $crate"; continue; }
            retry 2 cargo install "$crate" && log_ok "Installed: $crate" || track_failure "cargo" "Failed: $crate"
        done < "$CARGO_MANIFEST"
    else
        log_warn "Cargo not installed. Install Rust first: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    fi
fi

summarize_failures
ENDOFFILE

# ══════════════════════════════════════════════════════════════════════════════
# scripts/link-dotfiles.sh
# ══════════════════════════════════════════════════════════════════════════════
cat > "$TARGET/scripts/link-dotfiles.sh" << 'ENDOFFILE'
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
ENDOFFILE

# ══════════════════════════════════════════════════════════════════════════════
# scripts/restore.sh
# ══════════════════════════════════════════════════════════════════════════════
cat > "$TARGET/scripts/restore.sh" << 'ENDOFFILE'
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
ENDOFFILE

# ══════════════════════════════════════════════════════════════════════════════
# forge.sh (main entrypoint)
# ══════════════════════════════════════════════════════════════════════════════
cat > "$TARGET/forge.sh" << 'ENDOFFILE'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

print_usage() {
    cat << 'EOF'

  ╔═══════════════════════════════════════╗
  ║          i 3 - f o r g e             ║
  ║   Reproducible i3 Fedora Setup       ║
  ╚═══════════════════════════════════════╝

  Usage:
    ./forge.sh <command> [options]

  Commands:
    discover              Scan this system and capture packages, configs, dotfiles
    restore               Restore everything on a fresh machine
    restore --only <X>    Restore only one layer: dnf | flatpak | source | dotfiles
    link                  Re-symlink dotfiles into $HOME
    status                Show what's been captured

EOF
}

cmd_status() {
    echo "  Manifests:"
    for f in "$SCRIPT_DIR/manifests"/*; do [[ -f "$f" ]] && echo "    $(basename "$f"): $(wc -l < "$f") lines"; done
    echo "  Dotfiles:"
    if [[ -d "$SCRIPT_DIR/dotfiles" ]]; then
        find "$SCRIPT_DIR/dotfiles" -type f | wc -l | xargs -I{} echo "    {} files captured"
    else echo "    (none yet — run ./forge.sh discover)"; fi
}

case "${1:-}" in
    discover)   bash "$SCRIPT_DIR/scripts/discover.sh" ;;
    restore)    shift; bash "$SCRIPT_DIR/scripts/restore.sh" "$@" ;;
    link)       bash "$SCRIPT_DIR/scripts/link-dotfiles.sh" ;;
    status)     cmd_status ;;
    -h|--help|help|"") print_usage ;;
    *)          echo "Unknown command: $1"; print_usage; exit 1 ;;
esac
ENDOFFILE

# ── Make everything executable ───────────────────────────────────────────────
chmod +x "$TARGET/forge.sh" "$TARGET/scripts/"*.sh

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "  ✅ i3-forge created at: $TARGET"
echo ""
echo "  Structure:"
find "$TARGET" -type f | sed "s|$TARGET/||" | sort | while read -r f; do echo "    $f"; done
echo ""
echo "  Next steps:"
echo "    cd $TARGET"
echo "    git init"
echo "    ./forge.sh discover"
echo ""
