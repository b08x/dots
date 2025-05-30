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

gum_info "ok, now to install some packages and gems"
sleep 1

gum_info "then run the ansible-playbook"

DISTRO=$( hostnamectl| awk '{ print $1,$2,$3 }'|grep "Operating System"|awk '{print $3}' )

export PATH+=":$HOME/.local/share/gem/ruby/3.4.0/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

export ANSIBLE_HOME="$HOME/.config/syncopated"
export ANSIBLE_PLUGINS="$ANSIBLE_HOME/plugins/modules"
export ANSIBLE_CONFIG="$ANSIBLE_HOME/ansible.cfg"
export ANSIBLE_INVENTORY="$ANSIBLE_HOME/inventory/dynamic_inventory.py"

BOOTSTRAP_PKGS=(
  'ansible'
  'base-devel'
  'ccache'
  'cmake'
  'git'
  'htop'
  'neovim'
  'net-tools'
  'python-pip'
  'reflector'
  'ruby-bundler'
  'rubygems'
  'rust'
  'wget'
  'zsh'
)

# install pre-requisite packages
sudo pacman -S --noconfirm --needed "${BOOTSTRAP_PKGS[@]}" --overwrite '*'

export PATH="$HOME/.gem/ruby/3.4.0/bin:$PATH"
export PATH="$HOME/.local/share/gem/ruby/3.4.0/bin:$PATH"

export GEM_HOME="$HOME/.gem"
export GEM_PATH="$HOME/.gem"


INSTALLED_GEMS=$(gem list | choose 0)

GEMS=(
  'activesupport'
  'awesome_print'
  'bcrypt_pbkdf'
  'childprocess'
  'ed25519'
  'eventmachine'
  'ffi'
  'fractional'
  'geo_coord'
  'highline'
  'i3ipc'
  'i18n'
  'kramdown'
  'logging'
  'minitest'
  'mocha'
  'multi_json'
  'nano-bots'
  'net-ssh'
  'parallel'
  'pastel'
  'pry'
  'pry-doc'
  'pycall'
  'rake'
  'rdoc'
  'rexml'
  'rouge'
  'sync'
  'sys-proctable'
  'tty-box'
  'tty-command'
  'tty-cursor'
  'tty-prompt'
  'tty-screen'
  'tty-tree'
)

# https://stackoverflow.com/a/42399479
mapfile -t DIFF < \
    <(comm -23 \
        <(IFS=$'\n'; echo "${GEMS[*]}" | sort) \
        <(IFS=$'\n'; echo "${INSTALLED_GEMS[*]}" | sort) \
    )


for gem in "${DIFF[@]}"; do
  gem install --user-install "$gem" || continue
done

if [ ! -d $ANSIBLE_HOME ]; then
  git clone --recursive git@github.com:syncopatedX/ansible.git $ANSIBLE_HOME
  cd $ANSIBLE_HOME && git checkout development
else
  echo "syncopated config already exists."
  cd $ANSIBLE_HOME && git checkout development && git fetch && git pull
fi

host="$(uname -n)"

ansible-playbook -K -i $ANSIBLE_HOME/inventory/dynamic_inventory.py $ANSIBLE_HOME/playbooks/full.yml --limit $host


