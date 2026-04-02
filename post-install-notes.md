# Post-Install Notes

Things that can't be fully automated. Do these after running `./forge.sh restore`.

## Manual Steps

- [ ] **SSH keys**: Copy from backup or generate new ones (`ssh-keygen -t ed25519`)
- [ ] **GPG keys**: Import from backup (`gpg --import private.key`)
- [ ] **Git credentials**: Set up `git config --global user.name` / `user.email` and credential helper
- [ ] **Browser login**: Sign into Firefox/Chrome to sync bookmarks, extensions, passwords
- [ ] **Flatpak permissions**: Some Flatpak apps may need Flatseal adjustments
- [ ] **Display setup**: Run `xrandr` or `arandr` to configure multi-monitor layout
- [ ] **Wallpaper**: Set wallpaper with `feh --bg-scale /path/to/wallpaper.jpg` (add to i3 config)
- [ ] **Fonts**: If using custom fonts, copy to `~/.local/share/fonts/` and run `fc-cache -fv`

## Known Quirks

<!-- Add notes about things that broke or needed tweaking -->
