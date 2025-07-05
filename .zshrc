export UU_ORDER="$UU_ORDER:~/.zshrc"

# Path to your oh-my-zsh installation.
export ZSH="/usr/share/oh-my-zsh"

hostname=$(hostname)

if [[ $hostname == "ninjabot" ]]; then
  ZSH_THEME="jaischeema"
elif [[ $hostname == "soundbot" ]]; then
  ZSH_THEME="strug"
elif [[ $hostname == "crambot" ]]; then
  ZSH_THEME="kphoen"
elif [[ $hostname == "lapbot" ]]; then
  ZSH_THEME="kphoen"
else
  ZSH_THEME="linuxonly"
fi

CASE_SENSITIVE="true"
ENABLE_CORRECTION="false"
DISABLE_UNTRACKED_FILES_DIRTY="true"

ZSH_CUSTOM="$HOME/.local/share/zsh"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as o many plugins slow down shell startup.
#consider adding common-aliases, copybuffer
plugins=(ansible bundler docker-compose copypath fd fzf ripgrep zsh-navigation-tools ruby history systemd web-search)

source $ZSH/oh-my-zsh.sh

# User configuration

for function in $ZSH_CUSTOM/functions/*; do
  source $function
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
autoload -U colors
colors

export CLICOLOR=1



setopt SHARE_HISTORY         # Share history between all sessions.
setopt HIST_IGNORE_DUPS      # Do not record an event that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS  # Delete an old recorded event if a new event is a duplicate.
setopt HIST_IGNORE_SPACE     # Do not record an event starting with a space.
setopt HIST_SAVE_NO_DUPS     # Do not write a duplicate event to the history file.
setopt HIST_VERIFY           # Do not execute immediately upon history expansion.
setopt APPEND_HISTORY        # append to history file (Default)
setopt HIST_NO_STORE         # Don't store history commands
setopt HIST_REDUCE_BLANKS    # Remove superfluous blanks from each command line being added to the history.

HISTORY_IGNORE="(ls|cd|pwd|exit|cd)*"


HISTFILE=~/.zhistory
HISTSIZE=10000
SAVEHIST=10000

export ERL_AFLAGS="-kernel shell_history enabled"

stty -ixon

bindkey -v
bindkey "^F" vi-cmd-mode

bindkey "^A" beginning-of-line
bindkey '^[[3~' delete-char
bindkey "^K" kill-line
bindkey "^R" history-incremental-search-backward
bindkey "^P" history-search-backward
bindkey "^Y" accept-and-hold
bindkey "^N" insert-last-word
bindkey "^Q" push-line-or-edit
bindkey -s "^T" "^[Isudo ^[A" # "t" for "toughguy"

setopt autocd autopushd pushdminus pushdsilent pushdtohome cdablevars
DIRSTACKSIZE=5

setopt extendedglob
unsetopt nomatch

# load custom completion functions
# fpath=(/usr/local/share/zsh/completion /usr/local/share/zsh/site-functions $fpath)

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
#alias open="xdg-open"
alias make="make -j`nproc`"
alias ninja="ninja -j`nproc`"
alias n="ninja"
alias c="clear"
alias rmpkg="sudo pacman -Rsn"
alias cleanch="sudo pacman -Scc"
alias fixpacman="sudo rm /var/lib/pacman/db.lck"

# Help people new to Arch
alias apt="man pacman"
alias apt-get="man pacman"
alias please="sudo"
alias tb="nc termbin.com 9999"

# Cleanup orphaned packages
alias cleanup="sudo pacman -Rsn (pacman -Qtdq)"

# Get the error messages from journalctl
alias jctl="journalctl -p 3 -xb"

# Recent installed packages
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"

# aliases
[[ -f ~/.aliases ]] && source ~/.aliases

[[ -f /usr/share/zsh/site-functions/git-flow-completion.zsh ]] && source /usr/share/zsh/site-functions/git-flow-completion.zsh

# completion; use cache if updated within 24h
autoload -Uz compinit
# Use a simpler approach to check if the file is older than 24 hours
if [ -f $HOME/.zcompdump ] && [ ! "$HOME/.zcompdump" -nt "$(date -d 'now - 24 hours' '+%Y%m%d%H%M.%S')" ]; then
  compinit -d $HOME/.zcompdump;
else
  compinit -C;
fi;

setopt nobeep

# automatically find new executables in path
zstyle ':completion:*' rehash true

# Color man pages
export LESS_TERMCAP_mb=$'\E[01;32m'
export LESS_TERMCAP_md=$'\E[01;32m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;47;34m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;36m'
export LESS=-R

useditor() {
  export EDITOR="$@"
  export GIT_EDITOR="$@"
  export SVN_EDITOR="$@"
  export VISUAL="$@"
}

if [[ ! -n $EDITOR || $EDITOR != "micro" ]]; then useditor micro; fi

[ -n "$DISPLAY" ] && export TERM="kitty" || export TERM=xterm
[ -n "$DISPLAY" ] && export TERMINAL="kitty" || export TERMINAL=xterm

TERMCMD="$TERMINAL"

[ -n "$DISPLAY" ] && export BROWSER="google-chrome-stable" || export BROWSER=links

eval "$(zoxide init zsh)"

export PYENV_ROOT="$HOME/.pyenv"
if [[ -d $PYENV_ROOT/bin ]]; then
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
  export PATH="$(pyenv root)/shims:$PATH"
  eval "$(pyenv init - zsh)"
fi

echo $PATH | grep -q "$HOME/.local/bin:" || export PATH="$HOME/.local/bin:$PATH"

export GEM_HOME="$HOME/.local/share/gem/ruby/3.4.0"
echo $PATH | grep -q "$HOME/.local/share/gem/ruby/3.4.0/bin:" || export PATH="$PATH:$HOME/.local/share/gem/ruby/3.4.0/bin"


if [[ $hostname == "ninjabot" ]]; then
  export LIBVA_DRIVER_NAME=i965
# elif [[ $hostname == "server2" ]]; then
#   export MY_VAR="value_for_server2"
# elif [[ $hostname == "laptop" ]]; then
#   export MY_VAR="value_for_laptop"
# else
#   export MY_VAR="default_value"
fi


if [ -f "$HOME/.config/claude/local/claude" ]; then
  alias claude="$HOME/.config/claude/local/claude"
fi


# bun completions
[ -s "/home/b08x/.bun/_bun" ] && source "/home/b08x/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

export PATH="$HOME/.local/bin:$PATH"
