#!/bin/sh
export UU_ORDER="$UU_ORDER:~/.profile"

# set -a
# set +a

#if [ -n "$(ls "$HOME"/.config/profile.d 2>/dev/null)" ]; then
#	for f in "$HOME"/.config/profile.d/*; do
#		# shellcheck source=/dev/null
#		. "$f"
#	done
#fi
#export NO_AT_BRIDGE=1
#export QT_SCALE_FACTOR=1.0
#export QT_FONT_DPI=96

# This value is now set in /etc/pofile
#export QT_QPA_PLATFORMTHEME=qt5ct

#export GTK2_RC_FILES="$HOME/.gtkrc-2.0"

export RAY_PARENT_SCRIPT_DIR="$HOME/Sessions/ray-scripts"

[[ -f ~/.cargo/env ]] && . ~/.cargo/env

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
