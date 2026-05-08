#!/usr/bin/env bash


#TODO:


#TODO: develop ansible playbook to install deps and setup env

# bootstrap installs yadm, clones repo

# yadm bootstrap; odds and ends an images or ansible provisioning doesn't cover

echo "installing oh-my-zsh"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

sleep 2

echo "install go"
$ curl https://go.dev/dl/go1.26.3.linux-amd64.tar.gz
$ rm -rf /usr/local/go && tar -C /usr/local -xzf go1.26.3.linux-amd64.tar.gz



echo "install cargo"
curl https://sh.rustup.rs -sSf | sh



echo "install bun"
sh -c "$(curl -fsSL https://bun.sh/install)"

sudo dnf install perl-core zoxide ranger ansible

cargo install exa gitui weathr
