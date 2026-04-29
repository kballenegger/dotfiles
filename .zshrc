# -----------------------------------------------------------------
# PRE-ZPREZTO CUSTOM ZSH CONFIGURATION
# -----------------------------------------------------------------

# Native site-functions come first
# NOTE: this must happen before initializing zprezto
if command -v brew >/dev/null 2>&1; then
    BREW_PREFIX="$(brew --prefix)"
    fpath=("$BREW_PREFIX/share/zsh/site-functions" $fpath)
    if [ -f "$BREW_PREFIX/etc/bash_completion.d/git-completion.bash" ]; then
        zstyle ':completion:*:*:git:*' script "$BREW_PREFIX/etc/bash_completion.d/git-completion.bash"
    fi
    unset BREW_PREFIX
fi


# -----------------------------------------------------------------
# ZPREZTO CONFIGURATION
# -----------------------------------------------------------------

source "$HOME/.zprezto/init.zsh"


# -----------------------------------------------------------------
# CUSTOM ZSH CONFIGURATION
# -----------------------------------------------------------------


# Exists function
function exists { which $1 &> /dev/null }

# Set interactive comments
set -k

# Disable shared histories
unsetopt share_history

# Deal with slow git completion
__git_files () {
    _wanted files expl 'local files' _files
}

# Source the common shell rc settings in .shellrc.
source ~/.shellrc

# Fix zsh annoying history behavior
h() { if [ -z "$*" ]; then history 1; else history 1 | egrep "$@"; fi; }

# Do not save space-prefixed commands to history
setopt HIST_IGNORE_SPACE

autoload -Uz up-line-or-beginning-search
autoload -Uz down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '\eOA' up-line-or-beginning-search
bindkey '\e[A' up-line-or-beginning-search
bindkey '\eOB' down-line-or-beginning-search
bindkey '\e[B' down-line-or-beginning-search

# Alt-left right supports new mappings of arrow keys
bindkey '\eml' emacs-backward-word
bindkey '\emr' emacs-forward-word


# -----------------------------------------------------------------
# AUTOJUMPING
# -----------------------------------------------------------------

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
    alias j=z
fi

# fzf config (auto-added)
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh


# -----------------------------------------------------------------
# SOURCING LOCAL .ZSHRC
# -----------------------------------------------------------------

if [ -f ~/.zshrc.local ]; then
    source ~/.zshrc.local
fi


# iTerm2 shell integration (mac-only; harmless no-op elsewhere)
test -e ${HOME}/.iterm2_shell_integration.zsh && source ${HOME}/.iterm2_shell_integration.zsh
