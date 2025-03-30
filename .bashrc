# If not running interactively, do not do anything
[[ $- != *i* ]] && return

 # Export systemd environment vars from ~/.config/environment.d/* (tty only)
[[ ${SHLVL} == 1 ]] && [ -z "${DISPLAY}" ] && export $(/usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator | xargs)

# Source aliases
source "${HOME}/.aliases"

# Plugin: pkgfile (command not found)
[ -f /usr/share/doc/pkgfile/command-not-found.bash ] && source /usr/share/doc/pkgfile/command-not-found.bash

# Options
shopt -s autocd                  # Auto cd
shopt -s cdspell                 # Correct cd typos
shopt -s checkwinsize            # Update windows size on command
shopt -s histappend              # Append History instead of overwriting file
shopt -s cmdhist                 # Bash attempts to save all lines of a multiple-line command in the same history entry
shopt -s extglob                 # Extended pattern
shopt -s no_empty_cmd_completion # No empty completion
shopt -s expand_aliases          # Expand aliases

# Ignore upper and lowercase when TAB completion
bind "set completion-ignore-case on"

# Colorize man pages (bat)
command -v bat &>/dev/null && export MANPAGER="sh -c \"col -bx | bat -l man -p\""
command -v bat &>/dev/null && export MANROFFOPT="-c"

# History
export HISTSIZE=1000                    # History will save N commands
export HISTFILESIZE=${HISTSIZE}         # History will remember N commands
export HISTCONTROL=ignoredups:erasedups # Ingore duplicates and spaces (ignoreboth)
export HISTTIMEFORMAT="%F %T "          # Add date to history

# History ignore list
export HISTIGNORE="&:ls:ll:la:cd:exit:clear:history:q:c"

# Init starship (except tty)
[[ ! $(tty) =~ /dev/tty[0-9]* ]] && command -v starship &>/dev/null && eval "$(starship init bash)"

# Start fish shell (https://wiki.archlinux.org/title/Fish#Modify_.bashrc_to_drop_into_fish)
if command -v fish &>/dev/null && [[ $(ps --no-header --pid=$PPID --format=comm) != "fish" && -z ${BASH_EXECUTION_STRING} && ${SHLVL} == 1 ]]; then
    shopt -q login_shell && LOGIN_OPTION=--login || LOGIN_OPTION=""
    exec fish $LOGIN_OPTION
fi

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"
. "$HOME/.cargo/env"

command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
&& eval "$(pyenv init -)"
