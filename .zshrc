


# -----------------------------------------------------------------
# OH-MY-ZSH CONFIGURATION
# -----------------------------------------------------------------

# Below are the oh-my-zsh specific configuration settings.


# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="pygmalion"

# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Set to this to use case-sensitive completion
# CASE_SENSITIVE="true"

# Comment this out to disable weekly auto-update checks
DISABLE_AUTO_UPDATE="true"

# Uncomment following line if you want to disable colors in ls
# DISABLE_LS_COLORS="true"

# Uncomment following line if you want to disable autosetting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
COMPLETION_WAITING_DOTS="true"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(git autojump osx ruby github lein brew gem rvm terminalapp)

if [ -f ~/.omz.local ]; then
    source ~/.omz.local
fi

source $ZSH/oh-my-zsh.sh



# -----------------------------------------------------------------
# CUSTOM ZSH CONFIGURATION
# -----------------------------------------------------------------

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

# -----------------------------------------------------------------
# SOURCING LOCAL .ZSHRC
# -----------------------------------------------------------------

if [ -f ~/.zshrc.local ]; then
    source ~/.zshrc.local
fi







# the end

