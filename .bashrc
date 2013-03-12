
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
    git_branch=`git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'`
    if [ $git_branch ]; then
        echo "•$git_branch"
    fi
}

# sexy prompt
export PS1='[\[\033[0;35m\]\h\[\033[0;36m\] \w\[\033[00m\]\[\033[33m\]$(parse_git_branch)\[\033[00m\]]\$ '


# -----------------------------------------------------------------
# AUTOJUMP AND BASH COMPLETION CONFIGURATION
# -----------------------------------------------------------------

# bash completion
if [ -f /usr/local/etc/bash_completion ]; then
    . /usr/local/etc/bash_completion
fi

# autojump
if [ -f /usr/local/etc/autojump ]; then
    . /usr/local/etc/autojump
fi


# -----------------------------------------------------------------
# SOURCING LOCAL .BASHRC
# -----------------------------------------------------------------

if [ -f ~/.bashrc.local ]; then
    source ~/.bashrc.local
fi



