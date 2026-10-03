#!/usr/bin/env bats

load helpers

setup() {
  make_env
  cp "$YADM_SRC/bootstrap.d/10-zsh.sh" "$T/yadm/bootstrap.d/"
  export SYNCOPATED_SYSTEM_OMZ=$T/no-system-omz
  stub curl 'out=; while [ $# -gt 0 ]; do [ "$1" = -o ] && out=$2; url=$1; shift; done
echo "curl $url" >>"$T/calls"; echo "#installer" >"$out"'
  stub sh 'echo "sh $* ZSH=$ZSH KEEP_ZSHRC=$KEEP_ZSHRC CHSH=$CHSH RUNZSH=$RUNZSH" >>"$T/calls"'
  printf 'original zshrc\n' >"$HOME/.zshrc"
}
teardown() { cleanup_env; }

run_zsh() { run bash "$T/yadm/bootstrap.d/10-zsh.sh" </dev/null; }

@test "installs both when neither is present, with unattended env" {
  run_zsh
  [ "$status" -eq 0 ]
  grep -q 'curl .*ohmyzsh.*install.sh' "$T/calls"
  grep -q "sh .* --unattended ZSH=$HOME/.oh-my-zsh KEEP_ZSHRC=yes CHSH=no RUNZSH=no" "$T/calls"
  grep -q 'curl .*zoxide.*install.sh' "$T/calls"
}

@test "never modifies ~/.zshrc" {
  before=$(md5sum <"$HOME/.zshrc")
  run_zsh
  [ "$(md5sum <"$HOME/.zshrc")" = "$before" ]
}

@test "skips oh-my-zsh when ~/.oh-my-zsh exists" {
  mkdir -p "$HOME/.oh-my-zsh"
  run_zsh
  [ "$status" -eq 0 ]
  ! grep -q ohmyzsh "$T/calls"
  grep -q zoxide "$T/calls"
}

@test "skips oh-my-zsh when the system install exists" {
  mkdir -p "$SYNCOPATED_SYSTEM_OMZ"
  run_zsh
  ! grep -q ohmyzsh "$T/calls"
}

@test "skips zoxide when it is on PATH" {
  mkdir -p "$HOME/.oh-my-zsh"
  stub zoxide 'true'
  run_zsh
  [ "$status" -eq 2 ]
  [ ! -s "$T/calls" ]
}

@test "skips zoxide when it is in ~/.local/bin" {
  mkdir -p "$HOME/.oh-my-zsh" "$HOME/.local/bin"
  printf '#!/bin/sh\n' >"$HOME/.local/bin/zoxide"
  chmod +x "$HOME/.local/bin/zoxide"
  run_zsh
  [ "$status" -eq 2 ]
}

@test "exits 2 and does nothing when everything is installed" {
  mkdir -p "$HOME/.oh-my-zsh"
  stub zoxide 'true'
  run_zsh
  [ "$status" -eq 2 ]
  [ ! -s "$T/calls" ]
}

@test "exits 1 when a download fails" {
  stub curl 'exit 22'
  run_zsh
  [ "$status" -eq 1 ]
}

@test "a zoxide failure still exits 1" {
  mkdir -p "$HOME/.oh-my-zsh"
  stub curl 'exit 22'
  run_zsh
  [ "$status" -eq 1 ]
  [[ $output == *"zoxide"* ]]
}
