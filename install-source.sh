#!/usr/bin/env bash
# install-source.sh — build and install tools from source using recipes
# Reads manifests/source-builds.yml (simple format, no YAML parser needed)

source "$(dirname "$0")/utils.sh"

log_section "Source Build Installation"

MANIFEST="$MANIFESTS_DIR/source-builds.yml"
BUILD_DIR="$HOME/.i3-forge/builds"

if [[ ! -f "$MANIFEST" ]]; then
    log_error "Source build manifest not found: $MANIFEST"
    log_info "Run './forge.sh discover' first, then fill in the recipes."
    exit 1
fi

mkdir -p "$BUILD_DIR"

# ── Simple YAML-ish parser ───────────────────────────────────────────────────
# We parse the file block by block. Each block starts with "- name:"
# This avoids needing yq or python-yaml.

current_name=""
current_git_url=""
current_binary_check=""
declare -a current_build_cmds=()
declare -a current_deps=()
in_build=false
in_deps=false

process_entry() {
    if [[ -z "$current_name" || -z "$current_git_url" ]]; then
        return
    fi

    # Skip if git_url is still the TODO placeholder
    if [[ "$current_git_url" == '""' || "$current_git_url" == "\"\"" ]]; then
        log_warn "Skipping $current_name — no git_url configured"
        return
    fi

    log_info "Processing: $current_name"

    # Check if already installed via binary_check
    if [[ -n "$current_binary_check" ]]; then
        check_cmd="${current_binary_check//\"/}"
        if eval "$check_cmd" &>/dev/null; then
            log_info "Already installed: $current_name (verified by: $check_cmd)"
            return
        fi
    fi

    # Install dependencies first
    if [[ ${#current_deps[@]} -gt 0 ]]; then
        log_info "Installing build dependencies for $current_name..."
        for dep in "${current_deps[@]}"; do
            dep="${dep//\"/}"
            dep="$(echo "$dep" | xargs)"
            if ! is_pkg_installed "$dep"; then
                sudo dnf install -y "$dep" &>/dev/null || \
                    track_failure "source-dep" "Failed to install dependency $dep for $current_name"
            fi
        done
    fi

    # Clone or update repo
    local repo_dir="$BUILD_DIR/$current_name"
    local git_url="${current_git_url//\"/}"

    if [[ -d "$repo_dir/.git" ]]; then
        log_info "Updating repo: $current_name"
        (cd "$repo_dir" && git pull --ff-only) || \
            (rm -rf "$repo_dir" && git clone "$git_url" "$repo_dir")
    else
        rm -rf "$repo_dir"
        if ! retry 2 git clone "$git_url" "$repo_dir"; then
            track_failure "source" "Failed to clone $git_url"
            return
        fi
    fi

    # Run build commands
    (
        cd "$repo_dir" || exit 1
        for cmd in "${current_build_cmds[@]}"; do
            cmd="${cmd//\"/}"
            cmd="$(echo "$cmd" | xargs)"
            [[ -z "$cmd" ]] && continue
            log_info "  Running: $cmd"
            if ! eval "$cmd"; then
                track_failure "source" "Build command failed for $current_name: $cmd"
                exit 1
            fi
        done
    ) || {
        track_failure "source" "Build failed for $current_name"
        return
    }

    # Verify
    if [[ -n "$current_binary_check" ]]; then
        check_cmd="${current_binary_check//\"/}"
        if eval "$check_cmd" &>/dev/null; then
            log_ok "Successfully built and installed: $current_name"
        else
            track_failure "source" "Build completed but binary check failed: $current_name"
        fi
    else
        log_ok "Built: $current_name (no binary_check configured)"
    fi
}

# ── Parse the file ───────────────────────────────────────────────────────────
while IFS= read -r line || [[ -n "$line" ]]; do
    # Strip carriage return
    line="${line//$'\r'/}"

    # New entry
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.*) ]]; then
        # Process previous entry
        process_entry
        # Reset
        current_name="${BASH_REMATCH[1]//\"/}"
        current_name="$(echo "$current_name" | xargs)"
        current_git_url=""
        current_binary_check=""
        current_build_cmds=()
        current_deps=()
        in_build=false
        in_deps=false
        continue
    fi

    if [[ "$line" =~ ^[[:space:]]*git_url:[[:space:]]*(.*) ]]; then
        current_git_url="${BASH_REMATCH[1]}"
        in_build=false; in_deps=false
        continue
    fi

    if [[ "$line" =~ ^[[:space:]]*binary_check:[[:space:]]*(.*) ]]; then
        current_binary_check="${BASH_REMATCH[1]}"
        in_build=false; in_deps=false
        continue
    fi

    if [[ "$line" =~ ^[[:space:]]*build_commands: ]]; then
        in_build=true; in_deps=false
        continue
    fi

    if [[ "$line" =~ ^[[:space:]]*dependencies: ]]; then
        in_deps=true; in_build=false
        continue
    fi

    # Collect list items
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+(.*) ]]; then
        item="${BASH_REMATCH[1]}"
        if $in_build; then
            current_build_cmds+=("$item")
        elif $in_deps; then
            current_deps+=("$item")
        fi
    fi

done < "$MANIFEST"

# Process last entry
process_entry

# ── Cargo packages ───────────────────────────────────────────────────────────
CARGO_MANIFEST="$MANIFESTS_DIR/cargo-packages.txt"
if [[ -f "$CARGO_MANIFEST" ]] && [[ -s "$CARGO_MANIFEST" ]]; then
    log_section "Cargo Packages"
    if command_exists cargo; then
        while IFS= read -r crate; do
            [[ -z "$crate" || "$crate" == \#* ]] && continue
            crate="$(echo "$crate" | xargs)"
            if command_exists "$crate"; then
                log_info "Already installed: $crate"
            else
                if retry 2 cargo install "$crate"; then
                    log_ok "Installed crate: $crate"
                else
                    track_failure "cargo" "Failed to install crate: $crate"
                fi
            fi
        done < "$CARGO_MANIFEST"
    else
        log_warn "Cargo not installed. Install Rust first: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        track_failure "cargo" "Cargo not available, skipping all cargo packages"
    fi
fi

echo ""
summarize_failures
