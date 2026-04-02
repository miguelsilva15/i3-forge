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
    discover --only <X>   Discover only one layer: dnf | flatpak | source | dotfiles | sysinfo
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
    discover)   shift; bash "$SCRIPT_DIR/scripts/discover.sh" "$@" ;;
    restore)    shift; bash "$SCRIPT_DIR/scripts/restore.sh" "$@" ;;
    link)       bash "$SCRIPT_DIR/scripts/link-dotfiles.sh" ;;
    status)     cmd_status ;;
    -h|--help|help|"") print_usage ;;
    *)          echo "Unknown command: $1"; print_usage; exit 1 ;;
esac
