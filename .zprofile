export UU_ORDER="$UU_ORDER:~/.zprofile"

echo $PATH | grep -q "$HOME/.local/bin:" || export PATH="$HOME/.local/bin:$PATH"

if [ -d $HOME/.cargo/bin ]; then
  PATH="$PATH:$HOME/.cargo/bin"
fi

export -U PATH

export QT_QPA_PLATFORMTHEME=qt5ct
export QT_PLATFORMTHEME=qt5ct
export QT_PLATFORM_PLUGIN=qt5ct

#TODO: so, with autologin, something needs to be done with unlocking the gnome-keyring....
if [ -x "$(command -v gnome-keyring-daemon)" ]; then

  export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/gcr/ssh
  export GPG_TTY="$TTY"

  if [[ $(id -u) -ne 0 ]]; then
     systemctl --user import-environment GPG_TTY SSH_AUTH_SOCK
  	dbus-update-activation-environment --all
  fi

  if ! pgrep -a "keyring" >/dev/null; then
  	eval "$(/usr/bin/gnome-keyring-daemon --replace --daemonize --components=pkcs11,secrets,ssh,gpg)"
  fi

  export GNOME_KEYRING_CONTROL GNOME_KEYRING_PID GPG_AGENT_INFO SSH_AUTH_SOCK

fi

# automatically run startx when logging in on tty1
# When Xorg is run in rootless mode, Xorg logs are saved to ~/.local/share/xorg/Xorg.log.
# However, the stdout and stderr output from the Xorg session is not redirected to this log.
# To re-enable redirection,
# start Xorg with the -keeptty flag and redirect the stdout and stderr output to a file:
# startx -- -keeptty >~/.xorg.log 2>&1

[[ -z "${DISPLAY}" ]] && [[ "${XDG_VTNR}" -eq 1 ]] && startx -- -keeptty >~/.xorg.log 2>&1
