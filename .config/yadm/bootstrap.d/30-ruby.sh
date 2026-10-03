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

RUBY_VERSION_WANTED=4.0.4
PACKAGES_FILE=$YADM_CONFIG_DIR/default-gems.txt
RBENV_ROOT=${RBENV_ROOT:-$HOME/.rbenv}
export RUBY_CONFIGURE_OPTS=${RUBY_CONFIGURE_OPTS:---with-openssl-dir=/usr}

PATH=$RBENV_ROOT/shims:$PATH
DID_WORK=0
FAILED=0

install_ruby() {
  if ! command -v rbenv >/dev/null 2>&1; then
    err "rbenv is not available"
    return 1
  fi

  if rbenv versions --bare | grep -qx "$RUBY_VERSION_WANTED"; then
    info "Ruby $RUBY_VERSION_WANTED is already installed"
    return 0
  fi

  info "Installing Ruby $RUBY_VERSION_WANTED"
  if rbenv install "$RUBY_VERSION_WANTED" </dev/null; then
    DID_WORK=1
    ok "Ruby $RUBY_VERSION_WANTED installed"
  else
    err "Failed to install Ruby $RUBY_VERSION_WANTED"
    return 1
  fi
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
    info "Installing $gem"
    if RBENV_VERSION="$RUBY_VERSION_WANTED" rbenv exec gem install --no-document "$gem" </dev/null; then
      DID_WORK=1
      ok "$gem installed"
    else
      err "$gem failed to install"
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
  install_ruby || return "$RC_FAILED"
  set_global || return "$RC_FAILED"
  write_gemrc || return "$RC_FAILED"
  install_gems || return "$RC_FAILED"
  ((FAILED)) && return "$RC_FAILED"
  ((DID_WORK)) && return "$RC_OK"
  return "$RC_SKIPPED"
}

main "$@"
