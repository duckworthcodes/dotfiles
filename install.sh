#!/usr/bin/env bash
# install.sh — set up this dotfiles rice on a fresh Fedora + Hyprland machine.
#
# Safe to re-run. Anything it would overwrite gets backed up first to
# ~/rice-backup-<timestamp>/. Nothing here deletes your files.
#
# Usage:
#   ./install.sh            interactive: asks before each optional stage
#   ./install.sh --yes      non-interactive: says yes to every stage
#   ./install.sh --core     only the core rice (skip Spotify/Discord/SDDM)

set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/rice-backup-$(date +%Y%m%d-%H%M%S)"
ASSUME_YES=0
CORE_ONLY=0

for arg in "$@"; do
    case "$arg" in
        --yes) ASSUME_YES=1 ;;
        --core) CORE_ONLY=1 ;;
        *) echo "unknown option: $arg" >&2; exit 1 ;;
    esac
done

c_bold=$'\033[1m'; c_dim=$'\033[2m'; c_reset=$'\033[0m'
c_ok=$'\033[32m'; c_warn=$'\033[33m'; c_err=$'\033[31m'

say()  { printf '%s\n' "${c_bold}==>${c_reset} $*"; }
info() { printf '%s\n' "${c_dim}    $*${c_reset}"; }
ok()   { printf '%s\n' "${c_ok}    - $*${c_reset}"; }
warn() { printf '%s\n' "${c_warn}    ! $*${c_reset}"; }
err()  { printf '%s\n' "${c_err}    x $*${c_reset}" >&2; }

ask() {
    # ask "question" -> 0 (yes) or 1 (no). Always yes with --yes.
    [ "$ASSUME_YES" = 1 ] && return 0
    printf '%s [y/N] ' "$1"
    read -r reply
    case "$reply" in y|Y|yes|Yes) return 0 ;; *) return 1 ;; esac
}

have() { command -v "$1" >/dev/null 2>&1; }

backup_if_exists() {
    # backup_if_exists <path relative to $HOME>
    local rel="$1" src="$HOME/$1"
    if [ -e "$src" ] && [ ! -L "$src" ]; then
        mkdir -p "$(dirname "$BACKUP_DIR/$rel")"
        mv "$src" "$BACKUP_DIR/$rel"
        info "backed up existing ~/$rel -> $BACKUP_DIR/$rel"
    elif [ -L "$src" ]; then
        rm -f "$src"
    fi
}

require_fedora() {
    if ! grep -qi fedora /etc/os-release 2>/dev/null; then
        warn "this script targets Fedora; other distros may need different package names"
    fi
}

# --------------------------------------------------------------------------
say "Crimson Hyprland rice installer"
info "dotfiles dir: $DOTFILES_DIR"
info "backups (if any) go to: $BACKUP_DIR"
require_fedora
echo

# 1. Core packages -----------------------------------------------------------
say "Stage 1/7: core packages"
CORE_PKGS="hyprland waybar kitty fuzzel mako hyprlock hypridle swaybg wlogout \
wlsunset cliphist wl-clipboard grim slurp satty brightnessctl playerctl \
fastfetch starship stow git fish network-manager-applet rofi \
xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-hyprland \
python3-pillow blueman bluez"

if ask "Install core packages with dnf now?"; then
    # shellcheck disable=SC2086
    sudo dnf install -y --skip-unavailable $CORE_PKGS
    ok "core packages requested (see above for anything skipped)"
    warn "if hyprpaper-like extras are missing, swaybg + wlsunset already cover wallpaper + night light"
else
    info "skipped -- make sure these are installed manually: $CORE_PKGS"
fi

# SwayNotificationCenter often needs a COPR on Fedora
if ask "Install SwayNotificationCenter (notification center)?"; then
    if ! sudo dnf install -y SwayNotificationCenter 2>/dev/null; then
        warn "not in default repos, trying the COPR (erikreider/SwayNotificationCenter)"
        sudo dnf copr enable -y erikreider/SwayNotificationCenter 2>/dev/null
        sudo dnf install -y SwayNotificationCenter || warn "could not install swaync -- check the COPR manually for your Fedora version"
    fi
fi

echo

# 2. Fonts --------------------------------------------------------------------
say "Stage 2/7: fonts"
if ask "Install JetBrainsMono Nerd Font?"; then
    FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
    mkdir -p "$FONT_DIR"
    TMP_ZIP="$(mktemp --suffix=.zip)"
    if curl -fsSL -o "$TMP_ZIP" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"; then
        unzip -oq "$TMP_ZIP" -d "$FONT_DIR"
        fc-cache -f >/dev/null
        ok "JetBrainsMono Nerd Font installed"
    else
        err "download failed -- check your connection and try again, or grab it from nerdfonts.com"
    fi
    rm -f "$TMP_ZIP"
fi

if ask "Install the Bibata cursor theme?"; then
    mkdir -p "$HOME/.local/share/icons"
    TMP_TAR="$(mktemp --suffix=.tar.xz)"
    if curl -fsSL -o "$TMP_TAR" \
        "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz"; then
        tar -xf "$TMP_TAR" -C "$HOME/.local/share/icons"
        gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic' 2>/dev/null
        ok "Bibata cursor installed and set"
    else
        warn "cursor download failed -- skipping, everything else still works"
    fi
    rm -f "$TMP_TAR"
fi
echo

# 3. Link the dotfiles with stow ---------------------------------------------
say "Stage 3/7: linking configs (stow)"

# back up anything stow would collide with
for rel in .config/hypr .config/waybar .config/fuzzel .config/mako \
           .config/kitty .config/wlogout .config/fastfetch .config/gtk-3.0 \
           .config/gtk-4.0 .config/rofi .config/swaync .config/nvim \
           .config/starship.toml .local/bin/theme .local/bin/clip-menu \
           .local/bin/shot-annotate .local/share/color-schemes/WallpaperA.colors \
           .local/share/color-schemes/WallpaperB.colors; do
    backup_if_exists "$rel"
done

(cd "$DOTFILES_DIR" && stow -v . 2>&1 | sed 's/^/    /') || {
    err "stow reported conflicts -- resolve them, then re-run this script"
}
ok "dotfiles linked into \$HOME"
echo

# 4. Wallpapers ----------------------------------------------------------------
say "Stage 4/7: wallpaper"
mkdir -p "$HOME/Pictures/wallpapers"
if [ -d "$DOTFILES_DIR/wallpapers" ]; then
    cp -n "$DOTFILES_DIR"/wallpapers/* "$HOME/Pictures/wallpapers/" 2>/dev/null
    ok "copied bundled wallpaper(s) into ~/Pictures/wallpapers"
fi
FIRST_WALL="$(find "$HOME/Pictures/wallpapers" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' \) | head -1)"
if [ -n "$FIRST_WALL" ]; then
    cp "$FIRST_WALL" "$HOME/Pictures/wallpaper.jpg"
    ok "set $(basename "$FIRST_WALL") as the active wallpaper"
    if have python3 && python3 -c "import PIL" 2>/dev/null; then
        chmod +x "$HOME/.local/bin/theme" 2>/dev/null
        "$HOME/.local/bin/theme" "$FIRST_WALL" --no-apply >/dev/null 2>&1 \
            && ok "generated the full color palette from it"
    fi
else
    warn "no wallpaper found -- drop an image in ~/Pictures/wallpapers and run: theme <file>"
fi
echo

# 5. Enable services ------------------------------------------------------------
say "Stage 5/7: services"
if ask "Enable Bluetooth service?"; then
    sudo systemctl enable --now bluetooth 2>/dev/null && ok "bluetooth enabled" \
        || warn "could not enable bluetooth -- check 'systemctl status bluetooth'"
fi
echo

# 6. Optional: Spotify / Discord / Neovim theming --------------------------------
if [ "$CORE_ONLY" = 0 ]; then
    say "Stage 6/7: optional app theming"

    if have nvim; then
        info "Neovim colorscheme is already linked via .config/nvim -- add to your init.lua if not present:"
        info '  pcall(vim.cmd.colorscheme, "wallpaper")'
    fi

    if ask "Set up Spicetify (Spotify theming)? Spotify must be installed and opened once first"; then
        if ! have spicetify && [ ! -x "$HOME/.spicetify/spicetify" ]; then
            curl -fsSL https://raw.githubusercontent.com/spicetify/spicetify-cli/master/install.sh | sh
        fi
        info "then run, filling in your Spotify path:"
        info '  ~/.spicetify/spicetify config current_theme wallpaper color_scheme wallpaper \'
        info '      inject_css 1 replace_colors 1 overwrite_assets 1'
        info '  ~/.spicetify/spicetify backup apply'
        warn "spotify_path / prefs_path differ for Flatpak vs native installs -- see the repo README"
    fi

    if ask "Patch Discord with Vencord (theming, optional and against Discord's ToS)?"; then
        sh -c "$(curl -fsSL https://vencord.dev/install.sh)" || \
            warn "installer failed -- see github.com/Vencord/Installer for the current command"
    fi
    echo
fi

# 7. Optional: SDDM login theme --------------------------------------------------
if [ "$CORE_ONLY" = 0 ] && have sddm; then
    say "Stage 7/7: SDDM login screen"
    if ask "Install the generated SDDM theme (test-mode first, nothing enabled yet)?"; then
        if [ -d "$HOME/.config/theme/out/sddm" ]; then
            sudo mkdir -p /usr/share/sddm/themes/wallpaper
            sudo cp "$HOME/.config/theme/out/sddm"/* /usr/share/sddm/themes/wallpaper/
            ok "theme installed to /usr/share/sddm/themes/wallpaper"
            info "test it first, WITHOUT logging out:"
            info "  sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/wallpaper"
            info "only once that looks right, enable it with:"
            info '  printf "[Theme]\nCurrent=wallpaper\n" | sudo tee /etc/sddm.conf.d/zz-wallpaper.conf'
            warn "if the login screen ever breaks: Ctrl+Alt+F3, log in, then remove that file and restart sddm"
        else
            warn "no generated SDDM theme found -- run 'theme <wallpaper>' first, then re-run this stage"
        fi
    fi
    echo
fi

# --------------------------------------------------------------------------
say "Done"
if [ -d "$BACKUP_DIR" ]; then
    info "anything replaced during install was saved to: $BACKUP_DIR"
fi
info "log out and pick Hyprland at the login screen to start using it."
info "once logged in, sanity-check with: hyprctl configerrors"
