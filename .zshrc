



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
# DISABLE_AUTO_UPDATE="true"

# Uncomment following line if you want to disable colors in ls
# DISABLE_LS_COLORS="true"

# Uncomment following line if you want to disable autosetting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
# COMPLETION_WAITING_DOTS="true"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(git autojump osx ruby github lein brew gem rvm terminalapp)

source $ZSH/oh-my-zsh.sh

# Customize to your needs...
#export PATH=/var/www/server/current/scripts/bin:/usr/local/bin:/opt/local/bin:/opt/local/sbin:/Users/kenneth/.rvm/gems/ruby-1.9.3-preview1/bin:/Users/kenneth/.rvm/gems/ruby-1.9.3-preview1@global/bin:/Users/kenneth/.rvm/rubies/ruby-1.9.3-preview1/bin:/Users/kenneth/.rvm/bin:/Users/kenneth/.gem/ruby/1.8/bin:/usr/local/php/bin:/opt/local/lib/mysql5/bin:/usr/local/sbin:/usr/local/mysql/bin:/opt/local/apache2/bin:/usr/class/cs143/cool/bin:/Users/kenneth/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Users/kenneth/.rvm/bin





# This file contains the zsh settings, and
# sources the common shell rc settings in .shellrc.

source ~/.shellrc
