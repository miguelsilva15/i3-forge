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
