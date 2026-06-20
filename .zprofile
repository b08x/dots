export UU_ORDER="$UU_ORDER:~/.zprofile"

# automatically run startx when logging in on tty1 for X11-based desktops
# When Xorg is run in rootless mode, Xorg logs are saved to ~/.local/share/xorg/Xorg.log.
# However, the stdout and stderr output from the Xorg session is not redirected to this log.
# To re-enable redirection,
# start Xorg with the -keeptty flag and redirect the stdout and stderr output to a file:
# startx -- -keeptty >~/.xorg.log 2>&1


# Added by Antigravity CLI installer
export PATH="/home/b08x/.local/bin:$PATH"
