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
