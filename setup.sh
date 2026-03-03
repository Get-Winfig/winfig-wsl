#!/usr/bin/env bash
# ============================================================
#  Arch Linux WSL Bootstrap Script
# ============================================================
set -euo pipefail
IFS=$'\n\t'
clear

# ==============================
# Colors & Output Helpers
# ==============================

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

ICON_INFO="󰋽"
ICON_OK="󰄬"
ICON_WARN="󰀪"
ICON_ERR="󰅚"

info()    { echo -e "${BLUE}${ICON_INFO}  $1${NC}"; }
success() { echo -e "${GREEN}${ICON_OK}  $1${NC}"; }
warn()    { echo -e "${YELLOW}${ICON_WARN}  $1${NC}"; }
error()   { echo -e "${RED}${ICON_ERR}  $1${NC}"; }

trap 'error "An unexpected error occurred."' ERR
trap 'error "Setup interrupted by user."; exit 1' INT

# ==============================
# Banner
# ==============================

echo -e "${GREEN}"
echo "============================================================"
echo "  Arch Linux WSL Setup"
echo "============================================================"
echo -e "${NC}"

# ============================================================
#  Validation
# ============================================================

info "Validating environment..."

source /etc/os-release
if [[ "${ID:-}" != "arch" ]]; then
    error "This script is intended for Arch Linux only."
    exit 1
fi

if ! grep -qi microsoft /proc/version; then
    warn "WSL environment not detected."
fi

if ! sudo -v; then
    error "Sudo privileges are required."
    exit 1
fi

success "Environment validated"

# ============================================================
#  Utility Functions
# ============================================================

run_with_spinner() {
    "$@" >/dev/null 2>&1 &
    local pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        printf "."
        sleep 1
    done
    wait "$pid"
    echo
}

install_if_missing() {
    local pkg="$1"
    if ! pacman -Qi "$pkg" &>/dev/null; then
        info "Installing $pkg..."
        sudo pacman -S --noconfirm "$pkg" >/dev/null 2>&1
        success "Installed $pkg"
    else
        warn "$pkg already installed"
    fi
}

force_link() {
    local src="$1"
    local dest="$2"

    mkdir -p "$(dirname "$dest")"

    if [[ -e "$dest" || -L "$dest" ]]; then
        rm -rf "$dest"
    fi

    ln -s "$src" "$dest"
    success "Linked $(basename "$dest")"
}

# ============================================================
#  System Update
# ============================================================

info "Updating system..."
run_with_spinner sudo pacman -Syu --noconfirm
success "System updated"

# ============================================================
#  Core Package Installation
# ============================================================

PACKAGES=(
    base-devel
    git
    neovim
    python-pynvim
    zsh
    starship
    fzf
    fd
    zoxide
    tldr
    exa
    lazygit
    zellij
    fastfetch
    btop
    npm
    nodejs
    uv
    python3
)

info "Installing core packages..."
for pkg in "${PACKAGES[@]}"; do
    install_if_missing "$pkg"
done
success "Package installation complete"

# ============================================================
#  AUR Helper (yay)
# ============================================================

if ! command -v yay &>/dev/null; then
    info "Installing yay (AUR helper)..."
    cd /tmp
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si --noconfirm
    cd /tmp
    rm -rf yay-bin
    success "yay installed"
else
    warn "yay already installed"
fi

# ============================================================
#  Default Shell
# ============================================================

if [[ "$SHELL" != *zsh ]]; then
    info "Setting zsh as default shell..."
    chsh -s /bin/zsh
    success "Default shell set to zsh"
fi

# ============================================================
#  Windows User Detection
# ============================================================

if [[ -n "${SUDO_USER-}" ]]; then
    WINUSER="$SUDO_USER"
elif command -v cmd.exe &>/dev/null; then
    WINUSER=$(cmd.exe /C "echo %USERNAME%" 2>/dev/null | tr -d '\r')
else
    WINUSER="${USER:-}"
fi

WINHOME="/mnt/c/Users/$WINUSER"
DOTFILES="$WINHOME/.Dotfiles"
CONFIG_DIR="$HOME/.config"

mkdir -p "$CONFIG_DIR"

info "Windows user detected: $WINUSER"

# ============================================================
#  User Directory Symlinks
# ============================================================

USER_DIRS=(
    Desktop
    Documents
    Downloads
    Pictures
    Videos
    Music
    Templates
)

info "Linking user directories..."
for dir in "${USER_DIRS[@]}"; do
    if [[ -d "$WINHOME/$dir" ]]; then
        force_link "$WINHOME/$dir" "$HOME/$dir"
    fi
done

# ============================================================
#  Dotfiles Linking
# ============================================================

info "Linking configuration files..."

declare -A LINKS=(
    ["$DOTFILES/winfig-nvim"]="$HOME/.config/nvim"
    ["$DOTFILES/winfig-dots/Lazygit"]="$HOME/.config/lazygit"
    ["$DOTFILES/winfig-dots/Starship/starship.toml"]="$HOME/.config/starship.toml"
    ["$DOTFILES/winfig-dots/Git/gitconfig"]="$HOME/.gitconfig"
    ["$DOTFILES/winfig-dots/Git/catppuchin.gitconfig"]="$HOME/.catppuchin.gitconfig"
    ["$DOTFILES/winfig-dots/Git/gitignore"]="$HOME/.gitignore"
    ["$DOTFILES/winfig-dots/Git/gitmessage.txt"]="$HOME/.gitmessage.txt"
    ["$DOTFILES/winfig-dots/Git/tigrc"]="$HOME/.tigrc"
    ["$DOTFILES/winfig-dots/Bat/config"]="$HOME/.config/bat/config"
    ["$DOTFILES/winfig-dots/Bat/themes"]="$HOME/.config/bat/themes"
    ["$DOTFILES/winfig-dots/Zellij/config.kdl"]="$HOME/.config/zellij/config.kdl"
    ["$DOTFILES/winfig-dots/btop"]="$HOME/.config/btop"
)

for src in "${!LINKS[@]}"; do
    dest="${LINKS[$src]}"
    if [[ -e "$src" ]]; then
        force_link "$src" "$dest"
    fi
done

# ============================================================
#  Completion
# ============================================================

echo -e "\n${GREEN}============================================================"
echo "  Setup Completed Successfully"
echo "============================================================"
