#!/usr/bin/env bash

#TODO: develop ansible playbook to install deps and setup env

# bootstrap installs yadm, clones repo

# yadm bootstrap; odds and ends an images or ansible provisioning doesn't cover

echo "installing oh-my-zsh"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

sleep 2

echo "install bun"
sh -c "$(curl -fsSL https://bun.sh/install)"

sudo dnf install cargo perl-core zoxide ranger ansible

cargo install exa gitui weathr
