#!/usr/bin/env bash

# set a trap to exit with CTRL+C
ctrl_c() {
        echo "** End."
        sleep 1
}

trap ctrl_c INT SIGINT SIGTERM ERR EXIT

# --- Wipe Screen Function ---
wipe() {
  tput -S <<!
clear
cup 1
!
}

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

TOOLS="$HOME/Tools"

gum_info "ok, now to install some packages and gems"
sleep 1

gum_info "then run the ansible-playbook"

# export ANSIBLE_HOME="$HOME/.config/syncopated/ansible"
# export ANSIBLE_PLUGINS="$ANSIBLE_HOME/plugins/modules"
# export ANSIBLE_CONFIG="$ANSIBLE_HOME/ansible.cfg"
# export ANSIBLE_INVENTORY="$ANSIBLE_HOME/inventory/dynamic_inventory.py"

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

export GEM_HOME="$HOME/.local/share/gem/ruby/3.4.0"
export PATH="$HOME/.local/share/gem/ruby/3.4.0/bin:$PATH"

INSTALLED_GEMS=$(gem list --config-file ~/.gemrc | choose 0)

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
  'i18n'
  'i3ipc'
  'irb'
  'kramdown'
  'logging'
  'minitest'
  'mocha'
  'multi_json'
  'net-ssh'
  'parallel'
  'pastel'
  'pry-doc'
  'pry'
  'pycall'
  'rake'
  'rdoc'
  'rexml'
  'rouge'
  'rubocop'
  'ruby_llm'
  'ruby-lsp'
  'solargraph'
  'sublayer'
  'sync'
  'sys-proctable'
  'tty-box'
  'tty-command'
  'tty-cursor'
  'tty-prompt'
  'tty-screen'
  'tty-tree'
)

install_gems() {
  # https://stackoverflow.com/a/42399479
    mapfile -t DIFF < \
        <(comm -23 \
            <(IFS=$'\n'; echo "${GEMS[*]}" | sort) \
            <(IFS=$'\n'; echo "${INSTALLED_GEMS[*]}" | sort) \
        )


    for gem in "${DIFF[@]}"; do
      gem install --user-install "$gem" --conservative || continue
    done
}

if gum_confirm "install Gems?"; then install_gems; fi


# if [ ! -d $ANSIBLE_HOME ]; then
#   gum_info "cloning Ansible collection"
#   git clone --recursive git@github.com:syncopatedX/ansible.git $ANSIBLE_HOME
#   cd $ANSIBLE_HOME && git checkout development
# else
#   gum_yellow "ansible collection already exists, updating..."
#   cd $ANSIBLE_HOME && git checkout development && git fetch && git pull
# fi

host="$(uname -n)"

wipe

gum_green "starting full playbook run"

gum_yellow "todo"

sleep 1

#cd $ANSIBLE_HOME && \
#ansible-playbook -K -i inventory/dynamic_inventory.py playbooks/full.yml --limit $host


