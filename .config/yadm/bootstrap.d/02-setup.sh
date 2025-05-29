#!/usr/bin/env bash

source $HOME/.config/yadm/bootstrap.d/gum_wrapper.sh

DISTRO=$( hostnamectl| awk '{ print $1,$2,$3 }'|grep "Operating System"|awk '{print $3}' )

export PATH+=":$HOME/.local/share/gem/ruby/3.4.0/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

export ANSIBLE_HOME="$HOME/.config/syncopated"
export ANSIBLE_PLUGINS="$ANSIBLE_HOME/plugins/modules"
export ANSIBLE_CONFIG="$ANSIBLE_HOME/ansible.cfg"
export ANSIBLE_INVENTORY="$ANSIBLE_HOME/inventory.ini"

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
sudo pacman -S --noconfirm --needed "${BOOTSTRAP_PKGS[@]}"

export GEM_HOME="${HOME}/.gem"

# install ruby gems
echo "gem: --user-install --no-document" | sudo tee /root/.gemrc

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
  gem install "$gem" || continue
done

if [ ! -d $ANSIBLE_HOME ]; then
  git clone --recursive git@github.com:syncopatedX/ansible.git $ANSIBLE_HOME
  cd $ANSIBLE_HOME && git checkout development
else
  echo "syncopated config already exists."
  cd $ANSIBLE_HOME && git checkout development && git fetch && git pull
fi

host="$(uname -n)"

echo "$host ansible_user=$USER ansible_connection=local" > $ANSIBLE_INVENTORY

ansible-playbook -K -i $ANSIBLE_INVENTORY $ANSIBLE_HOME/playbooks/full.yml --limit $host

