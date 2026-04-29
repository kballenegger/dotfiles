
# This file contains the BASH-specific settings, and
# sources the common shell rc settings in .shellrc.

source ~/.shellrc


# -----------------------------------------------------------------
# BASH CONFIGURATION
# -----------------------------------------------------------------

# history
export HISTCONTROL=erasedups
export HISTSIZE=10000
export HISTTIMEFORMAT='%F %T '
shopt -s histappend


# -----------------------------------------------------------------
# BASH PROMPT
# -----------------------------------------------------------------

parse_git_branch() {
    git_branch=$(git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')
    if [ -n "$git_branch" ]; then
        echo "•$git_branch"
    fi
}

# sexy prompt
export PS1='[\[\033[0;35m\]\h\[\033[0;36m\] \w\[\033[00m\]\[\033[33m\]$(parse_git_branch)\[\033[00m\]]\$ '


# -----------------------------------------------------------------
# BASH COMPLETION
# -----------------------------------------------------------------

# bash-completion v2 (homebrew on mac, distro packages on linux)
if [ -n "${BREW_PREFIX:-}" ] || command -v brew >/dev/null 2>&1; then
    _bcp="$(brew --prefix 2>/dev/null)"
    if [ -r "$_bcp/etc/profile.d/bash_completion.sh" ]; then
        . "$_bcp/etc/profile.d/bash_completion.sh"
    elif [ -r "$_bcp/etc/bash_completion" ]; then
        . "$_bcp/etc/bash_completion"
    fi
    unset _bcp
elif [ -r /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
elif [ -r /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# fzf config (auto added)
[ -f ~/.fzf.bash ] && source ~/.fzf.bash


# -----------------------------------------------------------------
# SOURCING LOCAL .BASHRC
# -----------------------------------------------------------------

if [ -f ~/.bashrc.local ]; then
    source ~/.bashrc.local
fi
