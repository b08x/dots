# Shared bats helpers: a throwaway HOME and yadm tree, and stubs on a minimal PATH.

YADM_SRC=$(cd "$BATS_TEST_DIRNAME/.." && pwd)

# make_env: create $T (tree), $HOME, $T/bin (core tools + stubs) and a copy of
# the yadm config under $T/yadm. gum is deliberately not on PATH.
make_env() {
  ORIG_PATH=$PATH
  T=$(mktemp -d)
  export T HOME=$T/home USER=tester
  mkdir -p "$HOME" "$T/bin" "$T/yadm/scripts" "$T/yadm/bootstrap.d"
  local tool path
  for tool in bash env sed awk grep cat mktemp date dirname readlink find sort rm mkdir cp id cut basename sleep tput chmod mv touch head tr wc tee md5sum ln; do
    path=$(type -P "$tool") && ln -sf "$path" "$T/bin/$tool"
  done
  export PATH=$T/bin
  export SYNCOPATED_NO_ANIM=1
  : >"$T/calls"
  cp "$YADM_SRC/scripts/syncopated-theme.sh" "$YADM_SRC/scripts/gum-helpers.sh" "$T/yadm/scripts/"
}

# stub NAME BODY: create an executable stub in $T/bin.
stub() {
  printf '#!/bin/bash\n%s\n' "$2" >"$T/bin/$1"
  chmod +x "$T/bin/$1"
}

cleanup_env() {
  PATH=$ORIG_PATH
  rm -rf "$T"
}
