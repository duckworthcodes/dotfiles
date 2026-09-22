# crimson — a wallpaper-driven Hyprland rice

Fedora + Hyprland (Lua config), fully themed from a single wallpaper. Pick a
new wallpaper, and the bar, launcher, notifications, lock screen, terminal,
editor, Dolphin, Firefox, Spotify, Discord, and even the login screen all
recolor to match it.

Palette on the first wallpaper: crimson `#f94555`, cream `#f0d5a8`, maroon
`#3b2226`, sage `#8fa896`. Every other wallpaper generates its own palette
the same way — see [How theming works](#how-theming-works).

## Quick start (fresh machine)

```bash
git clone <this repo> ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh` is interactive and safe to re-run — anything it would overwrite
gets backed up to `~/rice-backup-<timestamp>/` first, never deleted. Flags:

- `./install.sh --yes` — accept every stage, no prompts
- `./install.sh --core` — only the core rice; skips Spotify/Discord/SDDM

It installs packages, fonts, and the cursor theme, links every config with
`stow`, sets up your first wallpaper, and prints (rather than blindly runs)
the extra steps Spicetify, Vencord, and the SDDM theme need, since those
depend on how Spotify/Discord/SDDM are installed on that machine.

## What's in here

| Path | What it is |
|------|------------|
| `.config/hypr/` | Hyprland config (`hyprland.lua`), hyprlock, hypridle |
| `.config/waybar/` | Floating pill bar — workspaces, window title, music, clock, tray, volume, network, cpu/mem, battery, notification bell, power button |
| `.config/fuzzel/` | App launcher |
| `.config/mako/` or `.config/swaync/` | Notifications (swaync adds a control-center panel: DND, buttons grid, volume/brightness sliders) |
| `.config/kitty/` | Terminal — transparent, runs fastfetch on open |
| `.config/wlogout/` | Power menu |
| `.config/fastfetch/` | System info theme |
| `.config/gtk-3.0/`, `.config/gtk-4.0/` | GTK color overrides |
| `.config/rofi/` | Wallpaper-picker theme (thumbnail grid) |
| `.config/nvim/colors/wallpaper.lua` | Generated Neovim colorscheme |
| `.config/starship.toml` | Shell prompt |
| `.local/bin/theme` | **The theme engine** — see below |
| `.local/bin/clip-menu` | Clipboard history picker (cliphist + fuzzel) |
| `.local/bin/shot-annotate` | Screenshot + annotate (grim + slurp + satty) |
| `.local/share/color-schemes/` | Generated Qt/KDE color scheme (Dolphin etc.) |
| `wallpapers/` | Bundled wallpaper(s) |
| `install.sh` | Fresh-machine setup script |

## How theming works

`~/.local/bin/theme` is a Python script that:

1. Extracts a palette from a wallpaper (accent, background, surface, text,
   and ANSI colors) by quantizing the image and picking the most saturated
   color as the accent.
2. Renders that palette into every app's config format (CSS, INI, JSON,
   Lua, QML...) from templates baked into the script.
3. Writes the wallpaper into `~/Pictures/wallpaper.jpg`, reloads each
   running app, and (for Qt apps) alternates between two generated KDE
   color-scheme names so KDE always notices the change.

```bash
theme ~/Pictures/wallpapers/some-image.jpg   # apply a specific wallpaper
theme pick                                    # thumbnail grid (rofi), click to apply
theme random                                  # random wallpaper from the folder
theme next / theme prev                       # step through the folder in order
theme <image> --dry-run                       # print the palette, change nothing
```

Wallpapers live in `~/Pictures/wallpapers/` (JPG/PNG/WebP). Drop new images
in any time — no re-running anything needed, they just show up in `pick`/
`next`/`prev`.

First-run backups of anything the script overwrites land in
`~/.config/theme/backup/` (once per file — later runs don't re-backup).

## Keybinds (mainMod = SUPER)

**Apps & launching**
- `SUPER + Return` — terminal · `SUPER + Space` — launcher · `SUPER + E` — files
- `SUPER + C` — clipboard history · `SUPER + BACKSPACE` — rofi run mode

**Windows**
- `SUPER + Q` — close · `SUPER + V` — float toggle
- `SUPER + F` — fullscreen · `SUPER + SHIFT + F` — maximize
- `SUPER + H/L` — focus left/right · `SUPER + [1-0]` — workspace

**Wallpaper / theme**
- `SUPER + W` — thumbnail picker · `SUPER + SHIFT + W` — random
- `SUPER + ]` / `SUPER + [` — next / previous wallpaper

**System**
- `SUPER + L` — lock (hyprlock) · `SUPER + X` — power menu (wlogout)
- `SUPER + N` — notification panel (swaync) or dismiss (mako)
- `ALT + Print` — screenshot + annotate · `Print` — region to clipboard

## Restoring a wallpaper's originals

Every config `theme` touches has a one-time backup in
`~/.config/theme/backup/` (mirrors the real path, e.g.
`~/.config/theme/backup/.config/waybar/style.css`). To fully undo the
theme engine's changes:

```bash
cp -r ~/.config/theme/backup/. ~/
```

## Known gotchas

- **Monitor** is hardcoded for a 1920x1080 @ 120Hz laptop panel (`eDP-1`) —
  change it in `hyprland.lua` on other hardware.
- **Spicetify / Vencord** modify Spotify/Discord clients directly; both can
  be undone (`spicetify restore`, re-run the Vencord installer to unpatch)
  and both need re-applying after the app updates.
- **SDDM theme** is generated but never auto-enabled — test with
  `sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/wallpaper`
  before flipping it on. If the login screen ever breaks: `Ctrl+Alt+F3`,
  log in, `sudo rm /etc/sddm.conf.d/zz-wallpaper.conf`, `sudo systemctl
  restart sddm`.
- **Firefox** transparency depends on the Firefox version — some releases
  ignore custom toolbar transparency on Wayland even with the right
  `about:config` flags set.
- Keep API keys and shell secrets out of this repo.
