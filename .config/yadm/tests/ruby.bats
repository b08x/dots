#!/usr/bin/env bats

load helpers

setup() {
  make_env
  cp "$YADM_SRC/bootstrap.d/01-ruby.sh" "$T/yadm/bootstrap.d/"
  mkdir -p "$T/yadm/files"
  cp "$YADM_SRC/files/default-gems.txt" "$T/yadm/files/"
  cp "$YADM_SRC/files/ruby-system-packages.txt" "$T/yadm/files/"
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

run_ruby() { run bash "$T/yadm/bootstrap.d/01-ruby.sh" </dev/null; }

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

@test "defaults to system Ruby when ruby >= 4.0.0 is present and sets rbenv global to system" {
  stub ruby 'echo "ruby 4.0.7 (2026-09-15) [x86_64-linux]"'
  echo "4.0.4" >"$T/global"
  run_ruby
  [ "$status" -eq 0 ]
  [[ $output == *"Using system Ruby 4.0.7"* ]]
  grep -q '^rbenv global system' "$T/calls"
}

@test "skips downloading, compiling, and configuring rbenv when using system Ruby" {
  stub ruby 'echo "ruby 4.0.7 (2026-09-15) [x86_64-linux]"'
  echo "system" >"$T/global"
  : >"$T/versions"
  rm -f "$RBENV_ROOT/versions/4.0.4/etc/gemrc"
  run_ruby
  [ "$status" -eq 2 ]
  ! grep -q '^rbenv install' "$T/calls"
  ! grep -q '^rbenv global' "$T/calls"
  [ ! -f "$RBENV_ROOT/versions/4.0.4/etc/gemrc" ]
}

@test "installs missing gems via user-install to ~/.local/bin when using system Ruby" {
  stub ruby 'echo "ruby 4.0.7 (2026-09-15) [x86_64-linux]"'
  echo "system" >"$T/global"
  grep -vx rubocop "$T/installed" >"$T/installed.new"
  mv "$T/installed.new" "$T/installed"
  run_ruby
  [ "$status" -eq 0 ]
  [ "$(grep -c 'gem install' "$T/calls")" -eq 1 ]
  grep -q "gem install --user-install --bindir $HOME/.local/bin --no-document rubocop" "$T/calls"
}

@test "system Ruby exits 2 when all default gems and global are already in place" {
  stub ruby 'echo "ruby 4.0.7 (2026-09-15) [x86_64-linux]"'
  echo "system" >"$T/global"
  run_ruby
  [ "$status" -eq 2 ]
  ! grep -q 'gem install' "$T/calls"
  ! grep -q '^rbenv global' "$T/calls"
}

@test "a failing gem in system Ruby exits 1 and remaining gems are still attempted" {
  stub ruby 'echo "ruby 4.0.7 (2026-09-15) [x86_64-linux]"'
  echo "system" >"$T/global"
  : >"$T/installed"
  GEM_FAIL=solargraph run_ruby
  [ "$status" -eq 1 ]
  [ "$(grep -c 'gem install' "$T/calls")" -eq 7 ]
}

@test "USE_RBENV=1 opts into rbenv compilation even when system Ruby >= 4.0.0 is present" {
  stub ruby 'echo "ruby 4.0.7 (2026-09-15) [x86_64-linux]"'
  : >"$T/versions"
  export USE_RBENV=1
  run_ruby
  [ "$status" -eq 0 ]
  grep -q '^rbenv install 4.0.4' "$T/calls"
}

@test "--rbenv option opts into rbenv compilation even when system Ruby >= 4.0.0 is present" {
  stub ruby 'echo "ruby 4.0.7 (2026-09-15) [x86_64-linux]"'
  : >"$T/versions"
  run bash "$T/yadm/bootstrap.d/01-ruby.sh" --rbenv </dev/null
  [ "$status" -eq 0 ]
  grep -q '^rbenv install 4.0.4' "$T/calls"
}

@test "falls back to rbenv when system Ruby is < 4.0.0" {
  stub ruby 'echo "ruby 3.3.0 (2023-12-25) [x86_64-linux]"'
  : >"$T/versions"
  run_ruby
  [ "$status" -eq 0 ]
  grep -q '^rbenv install 4.0.4' "$T/calls"
}

@test "prompts interactively when system Ruby >= 4.0.0 is present and chooses system for global" {
  stub ruby 'echo "ruby 4.0.7 (2026-09-15) [x86_64-linux]"'
  echo "system" >"$T/global"
  stub gum 'echo "gum $*" >>"$T/calls"
if [ "$1" = "choose" ]; then
  echo "system (System Ruby 4.0.7)"
fi
exit 0'
  export SYNCOPATED_FORCE_INTERACTIVE=1
  run bash "$T/yadm/bootstrap.d/01-ruby.sh" </dev/null
  [ "$status" -eq 2 ]
  grep -q "gum choose --header Select global Ruby version: system (System Ruby 4.0.7) rbenv (Ruby 4.0.4)" "$T/calls"
  [[ $output == *"Using system Ruby 4.0.7"* ]]
  ! grep -q '^rbenv install' "$T/calls"
}

@test "prompts interactively when system Ruby >= 4.0.0 is present and chooses rbenv for global" {
  stub ruby 'echo "ruby 4.0.7 (2026-09-15) [x86_64-linux]"'
  echo "system" >"$T/global"
  : >"$T/versions"
  stub gum 'echo "gum $*" >>"$T/calls"
if [ "$1" = "choose" ]; then
  echo "rbenv (Ruby 4.0.4)"
elif [ "$1" = "spin" ]; then
  shift
  while [ "$1" != "--" ]; do shift; done
  shift
  "$@"
fi
exit 0'
  export SYNCOPATED_FORCE_INTERACTIVE=1
  run bash "$T/yadm/bootstrap.d/01-ruby.sh" </dev/null
  [ "$status" -eq 0 ]
  grep -q "gum choose --header Select global Ruby version: system (System Ruby 4.0.7) rbenv (Ruby 4.0.4)" "$T/calls"
  grep -q '^rbenv install 4.0.4' "$T/calls"
  grep -q '^rbenv global 4.0.4' "$T/calls"
}

@test "--global=system sets global to system Ruby" {
  stub ruby 'echo "ruby 4.0.7 (2026-09-15) [x86_64-linux]"'
  echo "4.0.4" >"$T/global"
  run bash "$T/yadm/bootstrap.d/01-ruby.sh" --global=system </dev/null
  [ "$status" -eq 0 ]
  grep -q '^rbenv global system' "$T/calls"
  [[ $output == *"Using system Ruby 4.0.7"* ]]
}

@test "--global=rbenv sets global to rbenv Ruby and compiles/installs gems" {
  stub ruby 'echo "ruby 4.0.7 (2026-09-15) [x86_64-linux]"'
  echo "system" >"$T/global"
  : >"$T/versions"
  run bash "$T/yadm/bootstrap.d/01-ruby.sh" --global=rbenv </dev/null
  [ "$status" -eq 0 ]
  grep -q '^rbenv install 4.0.4' "$T/calls"
  grep -q '^rbenv global 4.0.4' "$T/calls"
}

@test "SYNCOPATED_RUBY_GLOBAL=system sets global to system Ruby" {
  stub ruby 'echo "ruby 4.0.7 (2026-09-15) [x86_64-linux]"'
  echo "4.0.4" >"$T/global"
  SYNCOPATED_RUBY_GLOBAL=system run_ruby
  [ "$status" -eq 0 ]
  grep -q '^rbenv global system' "$T/calls"
  [[ $output == *"Using system Ruby 4.0.7"* ]]
}

@test "ruby system package list holds exactly the 12 system packages" {
  [ "$(grep -vc '^#' "$YADM_SRC/files/ruby-system-packages.txt")" -eq 12 ]
  for p in openssl-devel ruby-devel ruby-build-all ruby-build-rbenv \
           libtree-sitter-bash-devel libtree-sitter-devel libtree-sitter-javascript-devel \
           libtree-sitter-json-devel libtree-sitter-python-devel libtree-sitter-ruby-devel \
           libtree-sitter-toml-devel libtree-sitter-yaml-devel; do
    grep -qx "$p" "$YADM_SRC/files/ruby-system-packages.txt"
  done
}

@test "header declares needs-sudo for orchestrator pre-authentication" {
  grep -q '^# bootstrap: needs-sudo' "$T/yadm/bootstrap.d/01-ruby.sh"
}

@test "installs missing system dependencies via dnf when missing" {
  stub sudo 'echo "sudo $*" >>"$T/calls"; exit 0'
  stub dnf 'echo "dnf $*" >>"$T/calls"; exit 0'
  stub rpm 'echo "rpm $*" >>"$T/calls"; exit 1'

  run_ruby
  [ "$status" -eq 0 ]
  grep -q 'sudo dnf install -y openssl-devel ruby-devel ruby-build-all ruby-build-rbenv libtree-sitter-bash-devel libtree-sitter-devel libtree-sitter-javascript-devel libtree-sitter-json-devel libtree-sitter-python-devel libtree-sitter-ruby-devel libtree-sitter-toml-devel libtree-sitter-yaml-devel' "$T/calls"
  [[ $output == *"✓ Ruby system dependencies"* ]]
}

@test "skips system dependency installation when all packages are already installed" {
  stub sudo 'echo "sudo $*" >>"$T/calls"; exit 0'
  stub dnf 'echo "dnf $*" >>"$T/calls"; exit 0'
  stub rpm 'echo "rpm $*" >>"$T/calls"; exit 0'

  run_ruby
  [ "$status" -eq 2 ]
  ! grep -q 'dnf install' "$T/calls"
  [[ $output == *"All system dependencies are already installed"* ]]
}

@test "installs only the missing subset of system dependencies" {
  stub sudo 'echo "sudo $*" >>"$T/calls"; exit 0'
  stub dnf 'echo "dnf $*" >>"$T/calls"; exit 0'
  stub rpm '
    echo "rpm $*" >>"$T/calls"
    if [ "$2" = "ruby-devel" ] || [ "$2" = "openssl-devel" ]; then
      exit 0
    fi
    exit 1
  '

  run_ruby
  [ "$status" -eq 0 ]
  grep -q 'sudo dnf install -y ruby-build-all ruby-build-rbenv libtree-sitter-bash-devel libtree-sitter-devel libtree-sitter-javascript-devel libtree-sitter-json-devel libtree-sitter-python-devel libtree-sitter-ruby-devel libtree-sitter-toml-devel libtree-sitter-yaml-devel' "$T/calls"
  ! grep -q 'dnf install.*openssl-devel' "$T/calls"
  ! grep -E '^sudo dnf install.*(^|[[:space:]])ruby-devel([[:space:]]|$)' "$T/calls"
}

@test "fails with exit 1 when dnf install of system dependencies fails" {
  stub sudo 'echo "sudo $*" >>"$T/calls"; exit 1'
  stub dnf 'echo "dnf $*" >>"$T/calls"; exit 1'
  stub rpm 'echo "rpm $*" >>"$T/calls"; exit 1'

  run_ruby
  [ "$status" -eq 1 ]
  [[ $output == *"✗ Ruby system dependencies"* ]]
}

@test "--skip-deps skips system dependency check" {
  stub sudo 'echo "sudo $*" >>"$T/calls"; exit 0'
  stub dnf 'echo "dnf $*" >>"$T/calls"; exit 0'
  stub rpm 'echo "rpm $*" >>"$T/calls"; exit 1'

  run bash "$T/yadm/bootstrap.d/01-ruby.sh" --skip-deps </dev/null
  [ "$status" -eq 2 ]
  ! grep -q 'dnf install' "$T/calls"
  ! grep -q 'rpm -q' "$T/calls"
}

@test "SYNCOPATED_RUBY_SKIP_DEPS=1 skips system dependency check" {
  stub sudo 'echo "sudo $*" >>"$T/calls"; exit 0'
  stub dnf 'echo "dnf $*" >>"$T/calls"; exit 0'
  stub rpm 'echo "rpm $*" >>"$T/calls"; exit 1'

  SYNCOPATED_RUBY_SKIP_DEPS=1 run_ruby
  [ "$status" -eq 2 ]
  ! grep -q 'dnf install' "$T/calls"
  ! grep -q 'rpm -q' "$T/calls"
}



