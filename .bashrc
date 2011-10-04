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

# path
export PATH="/Users/kenneth/bin:$PATH"

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
# APACHE, MYSQL, PHP
# -----------------------------------------------------------------

# apache
export PATH="/opt/local/apache2/bin:$PATH"

# mysql
export PATH="/usr/local/bin:/usr/local/sbin:/usr/local/mysql/bin:$PATH"
export PATH="/opt/local/lib/mysql5/bin:$PATH"

alias mysql='mysql5'

# php-shell
alias php-shell="php-shell.sh"

# -----------------------------------------------------------------
# GIT, RUBY, NODE
# -----------------------------------------------------------------

# git
export GIT_EDITOR="vim"

alias gco="git checkout"
alias gps="git push"
alias gpl="git pull"
alias gm="git merge"
alias gcm="git commit -m"
alias gc="git commit"
alias gs="git status"
alias gd="git diff"
alias gcp="git cherry-pick"
alias ga="git add"
alias gmv="git mv"
alias grm="git rm"

# rubygems
export PATH="/Users/kenneth/.gem/ruby/1.8/bin:$PATH"

# rvm
if [[ -s /Users/kenneth/.rvm/scripts/rvm ]] ; then
    source /Users/kenneth/.rvm/scripts/rvm
fi

# node
export NODE_PATH="/usr/local/lib/node"

# -----------------------------------------------------------------
# AUTOJUMP CONFIGURATION
# -----------------------------------------------------------------

if [ -f `brew --prefix`/etc/autojump ]; then
    . `brew --prefix`/etc/autojump
fi

# -----------------------------------------------------------------
# MACPORTS CONFIGUREATION
# -----------------------------------------------------------------

export PATH="/opt/local/bin:/opt/local/sbin:$PATH"

if [ -f /opt/local/etc/bash_completion ]; then
    . /opt/local/etc/bash_completion
fi


# -----------------------------------------------------------------
# CHARTBOOST-SPECIFIC CONFIGURATION
# -----------------------------------------------------------------

# bin path for scripts on server nodes
export PATH="/var/www/server/current/scripts/bin:$PATH"

# paraglide-live / dev
alias paraglide-live="export PARAGLIDE_ENVIRONMENT=live"
alias paraglide-dev="export PARAGLIDE_ENVIRONMENT=dev"

# misc shortcuts
alias remote-deploy="ssh cap 'cd server && cap production deploy'"
alias cd-cb="cd ~/dev/caffeine/server"
alias cd-current="cd /var/www/server/current"

# reverse proxy dev.chartboost.com:9999 traffic to localhost
alias cb-proxy='ssh -R 9999:localhost:80 dev -N'

# reverse proxy for xdebug sessions
alias xdebug-tunnel='ssh -R 19000:localhost:19000 dev -N'

# connect to mongo / chartboost
alias mcb='mongo localhost/chartboost'

# -----------------------------------------------------------------
# ALIASES
# -----------------------------------------------------------------

alias ssh-proxy='ssh -D 9999 azure -N'
alias ssh-reverse-http='ssh -R 9999:localhost:80 azure -N'
alias free='free -m'

function fgr {
    fgrep -r -n $@ .
}

function pbgist {
    if [ -z $1 ]; then
        _opt=""
    else
        _opt="-t $1"
    fi
    _out=`pbpaste | tab2space  | gist $_opt`
    echo $_out | pbcopy
    echo $_out
}

function macc {
    if [ -z $1]; then
        open /Applications/Macchiato.app
    else
        touch $1
        open -a /Applications/Macchiato.app $1
    fi
}

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


# -----------------------------------------------------------------
# PATH MANIPULATION FUNCTIONS
# -----------------------------------------------------------------

puniq () {
    echo "$1" |tr : '\n' |nl |sort -u -k 2,2 |sort -n |
    cut -f 2- |tr '\n' : |sed -e 's/:$//' -e 's/^://'
}

# condense PATH entries
PATH=$(puniq $PATH)
#MANPATH=$(puniq $MANPATH)


# -----------------------------------------------------------------
# SOURCING LOCAL .BASHRC
# -----------------------------------------------------------------

if [ -f ~/.bashrc.local ]; then
    source ~/.bashrc.local
fi


# -----------------------------------------------------------------
# AMAZON EC2 KEY PATHS
# -----------------------------------------------------------------

export EC2_PRIVATE_KEY="/var/www/server/current/config/amazon.key.pem"
export EC2_CERT="/var/www/server/current/config/amazon.cert.pem"


