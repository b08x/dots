#!/usr/bin/env bash
# 30-ruby.sh: install Ruby through rbenv, configure user-local gemrc for 4.0.4,
# and install the default gems listed in default-gems.txt.
#
# Exits 0 when something was done, 2 when everything was already in place,
# 1 on any failure. Gem failures do not stop the remaining gems.

set -uo pipefail

YADM_CONFIG_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..
# shellcheck source=../scripts/syncopated-theme.sh
source "$YADM_CONFIG_DIR/scripts/syncopated-theme.sh"

: "${SYNCOPATED_STEP:=ruby}"

RUBY_VERSION_WANTED=4.0.4
PACKAGES_FILE=$YADM_CONFIG_DIR/files/default-gems.txt
RBENV_ROOT=${RBENV_ROOT:-$HOME/.rbenv}
RUBY_TMPDIR=${RUBY_TMPDIR:-$RBENV_ROOT/tmp}
export RUBY_CONFIGURE_OPTS=${RUBY_CONFIGURE_OPTS:---with-openssl-dir=/usr}

PATH=$RBENV_ROOT/shims:$PATH
DID_WORK=0
FAILED=0
RUBY_TMPDIR_CREATED=""

cleanup_tmpdir() {
  if [[ -n $RUBY_TMPDIR_CREATED && -d $RUBY_TMPDIR_CREATED ]]; then
    rmdir "$RUBY_TMPDIR_CREATED" 2>/dev/null || true
  fi
}
trap cleanup_tmpdir EXIT

# can_execute_in DIR : verify that binaries or scripts can be executed in DIR.
# Returns 0 if execution succeeds, 1 if blocked (e.g. noexec mount).
can_execute_in() {
  local dir=$1 testfile rc=1
  [[ -d $dir && -w $dir ]] || return 1
  testfile=$(mktemp -p "$dir" .can_exec.XXXXXX 2>/dev/null) || return 1
  chmod 700 "$testfile" 2>/dev/null || { rm -f "$testfile"; return 1; }
  printf '#!/bin/sh\nexit 0\n' >"$testfile" 2>/dev/null
  if [[ -x $testfile ]] && "$testfile" 2>/dev/null; then
    rc=0
  fi
  rm -f "$testfile"
  return "$rc"
}

# setup_tmpdir : detect whether /tmp (or current TMPDIR) is mounted with noexec.
# When execution is blocked, configure and export TMPDIR to point to an executable
# directory under RBENV_ROOT so ruby-build, configure scripts, and native gem extensions succeed.
setup_tmpdir() {
  local current_tmp="${TMPDIR:-/tmp}"
  if ! can_execute_in "$current_tmp"; then
    local fallback_tmp="${RUBY_TMPDIR:-$RBENV_ROOT/tmp}"
    if [[ ! -d $fallback_tmp ]]; then
      mkdir -p "$fallback_tmp" || {
        err "Could not create temporary directory: $fallback_tmp"
        return 1
      }
      chmod 700 "$fallback_tmp" 2>/dev/null || true
      RUBY_TMPDIR_CREATED="$fallback_tmp"
    fi

    if ! can_execute_in "$fallback_tmp"; then
      err "Temporary directory $fallback_tmp does not permit execution"
      return 1
    fi

    export TMPDIR="$fallback_tmp"
    info "Configured TMPDIR=$TMPDIR ($current_tmp does not permit execution)"
  fi

  if [[ -n ${RUBY_BUILD_BUILD_PATH:-} ]] && ! can_execute_in "$RUBY_BUILD_BUILD_PATH"; then
    warn "RUBY_BUILD_BUILD_PATH ($RUBY_BUILD_BUILD_PATH) is not executable; unsetting"
    unset RUBY_BUILD_BUILD_PATH
  fi

  return 0
}

install_ruby() {
  if ! command -v rbenv >/dev/null 2>&1; then
    err "rbenv is not available"
    return 1
  fi

  if rbenv versions --bare | grep -qx "$RUBY_VERSION_WANTED"; then
    info "Ruby $RUBY_VERSION_WANTED is already installed"
    return 0
  fi

  run_item "Ruby $RUBY_VERSION_WANTED" rbenv install "$RUBY_VERSION_WANTED" || return 1
  DID_WORK=1
}

set_global() {
  if [[ $(rbenv global 2>/dev/null) == "$RUBY_VERSION_WANTED" ]]; then
    info "Global Ruby is already $RUBY_VERSION_WANTED"
    return 0
  fi

  info "Setting global Ruby to $RUBY_VERSION_WANTED"
  if rbenv global "$RUBY_VERSION_WANTED" && rbenv rehash </dev/null; then
    DID_WORK=1
    ok "Global Ruby set to $RUBY_VERSION_WANTED"
  else
    err "Failed to set global Ruby to $RUBY_VERSION_WANTED"
    return 1
  fi
}

write_gemrc() {
  local gemrc_file="$RBENV_ROOT/versions/$RUBY_VERSION_WANTED/etc/gemrc"
  local expected=$'---\ninstall: --user-install --bindir ~/.local/bin --env-shebang\nupdate: --user-install --bindir ~/.local/bin --env-shebang\n'

  if [[ ! -f $gemrc_file ]]; then
    mkdir -p "$(dirname "$gemrc_file")"
    printf '%s' "$expected" >"$gemrc_file"
    DID_WORK=1
    ok "Created $gemrc_file"
  elif cmp -s <(printf '%s' "$expected") "$gemrc_file"; then
    info "gemrc for $RUBY_VERSION_WANTED is already configured"
  else
    warn "$gemrc_file exists with unexpected content; leaving it unchanged"
  fi
}

install_gems() {
  if [[ ! -r $PACKAGES_FILE ]]; then
    err "Package list not found: $PACKAGES_FILE"
    return 1
  fi

  local wanted=() gem attempted=0
  mapfile -t wanted < <(sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$PACKAGES_FILE" | grep -v '^$')

  for gem in "${wanted[@]}"; do
    if RBENV_VERSION="$RUBY_VERSION_WANTED" rbenv exec gem list -i -e "$gem" >/dev/null 2>&1; then
      continue
    fi
    attempted=$((attempted + 1))
    if run_item "$(item_label "$gem")" env RBENV_VERSION="$RUBY_VERSION_WANTED" rbenv exec gem install --no-document "$gem"; then
      DID_WORK=1
    else
      FAILED=1
    fi
  done

  ((attempted == 0)) && info "All ${#wanted[@]} gems are already installed"
  if ((attempted > 0)); then
    rbenv rehash </dev/null || true
  fi
  return 0
}

main() {
  setup_tmpdir || return "$RC_FAILED"
  install_ruby || return "$RC_FAILED"
  set_global || return "$RC_FAILED"
  write_gemrc || return "$RC_FAILED"
  install_gems || return "$RC_FAILED"
  ((FAILED)) && return "$RC_FAILED"
  ((DID_WORK)) && return "$RC_OK"
  return "$RC_SKIPPED"
}

main "$@"
