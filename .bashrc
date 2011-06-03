# ----------------------------------------------------------------- #
#                                                                   #
#           Kenneth Ballenegger's Awesome .bashrc                   #
#                                                                   #
# ----------------------------------------------------------------- #


# -----------------------------------------------------------------
# BASH CONFIGURATION
# -----------------------------------------------------------------

export EDITOR="vim"

export CLICOLOR="xterm-color"
export DISPLAY=:0.0

# history
export HISTCONTROL=erasedups
export HISTSIZE=10000
shopt -s histappend

# sexy prompt
export PS1='[\[\033[0;35m\]\h\[\033[0;36m\] \w\[\033[00m\]]\$ '

# path
export PATH="/Users/kenneth/bin:$PATH"

# -----------------------------------------------------------------
# APACHE, MYSQL, PHP
# -----------------------------------------------------------------

# apache
export PATH="/opt/local/apache2/bin:$PATH"

# mysql
export PATH="/usr/local/bin:/usr/local/sbin:/usr/local/mysql/bin:$PATH"
export PATH=/opt/local/lib/mysql5/bin:$PATH

alias mysql='mysql5'

# php-shell
alias php-shell="php-shell.sh"

# -----------------------------------------------------------------
# GIT, RUBY, NODE
# -----------------------------------------------------------------

 # git
export GIT_EDITOR="vim"

# rubygems
export PATH="/Users/kenneth/.gem/ruby/1.8/bin:$PATH"

# node
export NODE_PATH="/usr/local/lib/node"

# -----------------------------------------------------------------
# MACPORTS CONFIGUREATION
# -----------------------------------------------------------------

export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
export MANPATH=/opt/local/share/man:$MANPATH

if [ -f /opt/local/etc/bash_completion ]; then
    . /opt/local/etc/bash_completion
fi

# -----------------------------------------------------------------
# CHARTBOOST-SPECIFIC CONFIGURATION
# -----------------------------------------------------------------

# bin path for scripts on server nodes
export PATH="/var/www/server/current/scripts/bin:$PATH"


# -----------------------------------------------------------------
# ALIASES
# -----------------------------------------------------------------

alias ssh-tunnel='ssh -D 9999 azure -N'
alias fgr='fgrep -r -n'
alias free='free -m'

# -----------------------------------------------------------------
# LS AND DIRCOLORS
# -----------------------------------------------------------------

# we always pass these to ls(1)
LS_COMMON="-hBG"

# setup the main ls alias if we've established common args
test -n "$LS_COMMON" &&
alias ls="command ls $LS_COMMON"

# these use the ls aliases above
alias ll="ls -l"
alias l.="ls -d .*"
alias ll.="ls -dl .*"
alias lla="ls -al"

# --- end LS ---

# -----------------------------------------------------------------
# PATH MANIPULATION FUNCTIONS
# -----------------------------------------------------------------

puniq () {
    echo "$1" |tr : '\n' |nl |sort -u -k 2,2 |sort -n |
    cut -f 2- |tr '\n' : |sed -e 's/:$//' -e 's/^://'
}

# condense PATH entries
PATH=$(puniq $PATH)
MANPATH=$(puniq $MANPATH)



