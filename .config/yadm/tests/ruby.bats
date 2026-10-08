#!/usr/bin/env bats

load helpers

setup() {
  make_env
  cp "$YADM_SRC/bootstrap.d/30-ruby.sh" "$T/yadm/bootstrap.d/"
  mkdir -p "$T/yadm/files"; cp "$YADM_SRC/files/default-gems.txt" "$T/yadm/files/"
  export RBENV_ROOT=$HOME/.rbenv
  mkdir -p "$RBENV_ROOT/versions/4.0.4/etc"
  echo "4.0.4" >"$T/versions"
  echo "4.0.4" >"$T/global"
  grep -v '^#' "$T/yadm/files/default-gems.txt" >"$T/installed"
  printf -- '---\ninstall: --user-install --bindir ~/.local/bin --env-shebang\nupdate: --user-install --bindir ~/.local/bin --env-shebang\n' >"$RBENV_ROOT/versions/4.0.4/etc/gemrc"

  # Stub rbenv
  stub rbenv 'if [ "$1" = "versions" ]; then
  cat "$T/versions"
elif [ "$1" = "global" ]; then
  if [ $# -eq 1 ]; then
    cat "$T/global"
  else
    echo "rbenv global $2" >>"$T/calls"
    echo "$2" >"$T/global"
  fi
elif [ "$1" = "install" ]; then
  echo "rbenv install $2" >>"$T/calls"
  echo "$2" >>"$T/versions"
  mkdir -p "$RBENV_ROOT/versions/$2"
elif [ "$1" = "rehash" ]; then
  echo "rbenv rehash" >>"$T/calls"
elif [ "$1" = "exec" ]; then
  shift
  exec "$@"
fi'

  # Stub gem
  stub gem 'if [ "$1" = "list" ] && [ "$2" = "-i" ] && [ "$3" = "-e" ]; then
  grep -qx "$4" "$T/installed"
  exit $?
elif [ "$1" = "install" ]; then
  echo "RBENV_VERSION=${RBENV_VERSION:-} gem $*" >>"$T/calls"
  name="${*: -1}"
  if [ "$name" = "${GEM_FAIL:-none}" ]; then
    exit 1
  fi
  echo "$name" >>"$T/installed"
  exit 0
else
  echo "gem $*" >>"$T/calls"
  exit 0
fi'
}

teardown() { cleanup_env; }

run_ruby() { run bash "$T/yadm/bootstrap.d/30-ruby.sh" </dev/null; }

@test "package list holds exactly the 7 gems" {
  [ "$(grep -vc '^#' "$YADM_SRC/files/default-gems.txt")" -eq 7 ]
  for g in pry solargraph ruby-lsp rubocop bubblezone huh ntcharts; do
    grep -qx "$g" "$YADM_SRC/files/default-gems.txt"
  done
}


@test "rbenv install 4.0.4 runs when 4.0.4 is missing and is skipped when present" {
  : >"$T/versions"
  run_ruby
  [ "$status" -eq 0 ]
  grep -q '^rbenv install 4.0.4' "$T/calls"

  : >"$T/calls"
  echo "4.0.4" >"$T/versions"
  run_ruby
  ! grep -q '^rbenv install' "$T/calls"
}

@test "rbenv global 4.0.4 runs only when the global version differs" {
  echo "system" >"$T/global"
  run_ruby
  [ "$status" -eq 0 ]
  grep -q '^rbenv global 4.0.4' "$T/calls"

  : >"$T/calls"
  run_ruby
  ! grep -q '^rbenv global' "$T/calls"
}

@test "exactly the one missing gem is installed, and the install runs with RBENV_VERSION=4.0.4" {
  grep -vx rubocop "$T/installed" >"$T/installed.new"
  mv "$T/installed.new" "$T/installed"
  run_ruby
  [ "$status" -eq 0 ]
  [ "$(grep -c 'gem install' "$T/calls")" -eq 1 ]
  grep -qx 'RBENV_VERSION=4.0.4 gem install --no-document rubocop' "$T/calls"
}

@test "with no gemrc present, creates 4.0.4 etc/gemrc with install and update flags" {
  rm -f "$RBENV_ROOT/versions/4.0.4/etc/gemrc"
  run_ruby
  [ "$status" -eq 0 ]
  [ -f "$RBENV_ROOT/versions/4.0.4/etc/gemrc" ]
  grep -q '^install: --user-install --bindir ~/.local/bin --env-shebang' "$RBENV_ROOT/versions/4.0.4/etc/gemrc"
  grep -q '^update: --user-install --bindir ~/.local/bin --env-shebang' "$RBENV_ROOT/versions/4.0.4/etc/gemrc"
}

@test "a gemrc with matching content is left byte-identical, and the script exits 2" {
  before=$(md5sum <"$RBENV_ROOT/versions/4.0.4/etc/gemrc")
  run_ruby
  [ "$status" -eq 2 ]
  [ "$(md5sum <"$RBENV_ROOT/versions/4.0.4/etc/gemrc")" = "$before" ]
}

@test "a gemrc with different content is left unchanged and the script prints a warning" {
  printf 'custom: true\n' >"$RBENV_ROOT/versions/4.0.4/etc/gemrc"
  before=$(md5sum <"$RBENV_ROOT/versions/4.0.4/etc/gemrc")
  run_ruby
  [ "$(md5sum <"$RBENV_ROOT/versions/4.0.4/etc/gemrc")" = "$before" ]
  [[ $output == *"unexpected content"* ]]
}

@test "no gemrc is written into any other version directory" {
  mkdir -p "$RBENV_ROOT/versions/3.3.0/etc"
  run_ruby
  [ ! -e "$RBENV_ROOT/versions/3.3.0/etc/gemrc" ]
}

@test "the script exits 2 when everything is in place" {
  run_ruby
  [ "$status" -eq 2 ]
  ! grep -q 'install' "$T/calls"
}

@test "a failing gem gives exit 1 and the other gems are still attempted" {
  : >"$T/installed"
  GEM_FAIL=solargraph run_ruby
  [ "$status" -eq 1 ]
  [ "$(grep -c 'gem install' "$T/calls")" -eq 7 ]
}

@test "the script fails when rbenv is missing" {
  rm "$T/bin/rbenv"
  run_ruby
  [ "$status" -eq 1 ]
  [[ $output == *"rbenv is not available"* ]]
}

@test "the script never calls update --system" {
  : >"$T/installed"
  run_ruby
  ! grep -q 'update.*--system' "$T/calls"
}

@test "falls back to RUBY_TMPDIR when TMPDIR does not permit execution" {
  local noexec_tmp="$T/noexec_tmp"
  mkdir -p "$noexec_tmp"
  chmod 500 "$noexec_tmp"
  TMPDIR="$noexec_tmp" run_ruby
  [ "$status" -eq 2 ]
  [[ $output == *"Configured TMPDIR="* ]]
}

@test "unsets RUBY_BUILD_BUILD_PATH when pointing to non-executable directory" {
  local noexec_path="$T/noexec_path"
  mkdir -p "$noexec_path"
  chmod 500 "$noexec_path"
  RUBY_BUILD_BUILD_PATH="$noexec_path" run_ruby
  [ "$status" -eq 2 ]
  [[ $output == *"is not executable; unsetting"* ]]
}
