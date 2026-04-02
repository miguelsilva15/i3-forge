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
