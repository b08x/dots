#!/bin/sh
export UU_ORDER="$UU_ORDER:~/.profile"

export XDG_CONFIG_HOME=$HOME/.config

# make default editor micro
export EDITOR=micro

if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
    export MOZ_ENABLE_WAYLAND=1
    export MOZ_DBUS_REMOTE=1
    export GTK_CSD=0
    export QT_QPA_PLATFORM="wayland"
    export _JAVA_AWT_WM_NONREPARENTING=1
    # set ozone platform to wayland
	export ELECTRON_OZONE_PLATFORM_HINT=wayland
    # Add other Wayland specific variables here
    export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
    
elif [[ "$XDG_SESSION_TYPE" == "x11" ]]; then
	export QT_QPA_PLATFORM="xcb"
fi

export QT_QPA_PLATFORMTHEME=qt5ct

# set default shell and terminal
export SHELL=/usr/bin/zsh
export TERMINAL_COMMAND=xdg-terminal-exec

# add default location for zeit.db
export ZEIT_DB="$HOME/.config/zeit.db"

# Disable hardware cursors. This might fix issues with
# disappearing cursors
if systemd-detect-virt -q; then
    # if the system is running inside a virtual machine, disable hardware cursors
    export WLR_NO_HARDWARE_CURSORS=1
fi

export LIBVIRT_DEFAULT_URI=qemu:///system

# Disable warnings by OpenCV
export OPENCV_LOG_LEVEL=ERROR

set -a
. "$HOME/.config/user-dirs.dirs"
set +a

if [ -n "$(ls "$HOME"/.config/profile.d 2>/dev/null)" ]; then
    for f in "$HOME"/.config/profile.d/*; do
        # shellcheck source=/dev/null
        . "$f"
    done
fi

#!/bin/bash
# Initialize Intel oneAPI environment variables on login
#if [ -f /opt/intel/oneapi/setvars.sh ]; then
#    source /opt/intel/oneapi/setvars.sh > /dev/null 2>&1
#fi

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:/home/linuxbrew/.linuxbrew/lib/ruby/gems/3.4.0/bin"

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

if [ -f "$HOME/.local/share/../bin/env" ]; then
	. "$HOME/.local/share/../bin/env"
fi

if [ -d "$HOME/.rvm/bin" ]; then
	# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
	export PATH="$PATH:$HOME/.rvm/bin"
fi
