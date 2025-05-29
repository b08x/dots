#!/usr/bin/env bash

source $HOME/.config/yadm/bootstrap.d/gum_wrapper.sh

# Now you can use the gum functions
gum_init # Initialize gum (download if not present)

gum_title "yadm bootstrap"
gum_info "Setup the user home config."

if gum_confirm "Do you want to continue?"; then
    gum_green "User confirmed!"
else
    gum_warn "User did not confirm."
fi

DISTRO=$( hostnamectl| awk '{ print $1,$2,$3 }'|grep "Operating System"|awk '{print $3}' )

# make sure pip3 git and git-lfs are installed
hash git ruby mdadm&>/dev/null &&
echo "Looks like we have everything we need here." ||

if [ "$?" != 0 ];
then
  echo "something isn't installed...run case distro"
    case $DISTRO in
      Debian)
        sudo apt -y install git uv python3-venv lsb-release mdadm
        ;;
      Fedora)
        sudo dnf -y install python3-pip git lsb-release
        ;;
      Arch)
        sudo pacman -S git uv \
        			   rubygems ruby-bundler lsb-release mdadm \
        			   --noconfirm --overwrite '*'
        ;;
    esac
fi

# install cargo
if [ -x "$(command -v cargo)" ];
then
  echo "cargo is found!"
else
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o - | sh
fi

# install ansible if it isn't already available
if [ -x "$(command -v ansible)" ];
then
  gum_info "by the way, ansible is installed."
else
  #pipx install ansible-core || exit
  gum_warn "ansible is not installed."
fi

TOOLS="$HOME/Workspace/Tools"


