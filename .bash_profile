export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
export DISPLAY=:0.0
export PATH="/usr/local/bin:/usr/local/sbin:/usr/local/mysql/bin:$PATH"
export EDITOR="vi"
export GIT_EDITOR="vi"
export CLICOLOR="xterm-color"
export PATH="/opt/local/apache2/bin:$PATH"
export PATH="~/bin/:$PATH"
export HISTCONTROL=erasedups
export HISTSIZE=10000
export PATH="/Users/kenneth/bin:$PATH"
export PATH="/Users/kenneth/.gem/ruby/1.8/bin:$PATH"
shopt -s histappend

export PS1='[\[\033[0;35m\]\h\[\033[0;36m\] \w\[\033[00m\]]\$ '

export NODE_PATH="/usr/local/lib/node"

# MacPorts Installer addition on 2009-06-27_at_11:16:43: adding an appropriate MANPATH variable for use with MacPorts.
export MANPATH=/opt/local/share/man:$MANPATH
# Finished adapting your MANPATH environment variable for use with MacPorts.

if [ -f /opt/local/etc/bash_completion ]; then
    . /opt/local/etc/bash_completion
fi


# MacPorts Installer addition on 2010-06-12_at_18:38:32: adding an appropriate PATH variable for use with MacPorts.
export PATH=/opt/local/bin:/opt/local/sbin:$PATH
# Finished adapting your PATH environment variable for use with MacPorts.


alias mysql='mysql5'

alias ssh-tunnel='ssh -D 9999 azure -N'

alias fgr='fgrep -r -n'


# bashmarks
# source ~/.local/bin/bashmarks.sh

export PATH=/opt/local/lib/mysql5/bin:$PATH

# PHP-Shell
alias php-shell="php-shell.sh"

# Git autocompeltion

#source `brew --prefix git`/etc/bash_completion.d


