#!/usr/bin/env bash
#
# Install the CLI tools these dotfiles assume are present.
# Detects mac (homebrew), linux (apt or dnf), and skips anything already installed.
#
# Usage: bash ~/bin/setup-packages.sh

set -euo pipefail

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }

# Tools assumed by .shellrc / .zshrc / .vimrc / .tmux.conf.
# Names that differ across platforms are handled below.
COMMON=(
    git
    tmux
    zsh
    neovim
    jq
    fzf
    ripgrep
    tree
    htop
    curl
    wget
)

install_mac() {
    if ! command -v brew >/dev/null 2>&1; then
        log "Installing Homebrew"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
    fi

    log "Installing CLI tools via brew"
    brew install \
        "${COMMON[@]}" \
        ack \
        gh \
        zoxide \
        watchman \
        pngpaste \
        coreutils
}

install_apt() {
    log "Installing CLI tools via apt"
    sudo apt-get update -qq
    # ack-grep on older ubuntus; ack on newer.
    sudo apt-get install -y \
        "${COMMON[@]}" \
        ack \
        build-essential \
        xclip
    # zoxide isn't packaged on every distro version; use install script.
    if ! command -v zoxide >/dev/null 2>&1; then
        curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    fi
    # gh from official apt repo
    if ! command -v gh >/dev/null 2>&1; then
        warn "gh (github cli) not installed; see https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
    fi
}

install_dnf() {
    log "Installing CLI tools via dnf"
    sudo dnf install -y \
        "${COMMON[@]}" \
        ack \
        xclip
}

case "$(uname -s)" in
    Darwin) install_mac ;;
    Linux)
        if command -v apt-get >/dev/null 2>&1; then
            install_apt
        elif command -v dnf >/dev/null 2>&1; then
            install_dnf
        else
            warn "Unknown linux package manager — install manually: ${COMMON[*]}"
            exit 1
        fi
        ;;
    *) warn "Unsupported OS: $(uname -s)"; exit 1 ;;
esac

log "Done. Run 'chsh -s \"\$(command -v zsh)\"' to switch your default shell."
