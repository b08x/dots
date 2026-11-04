#!/usr/bin/env bats

load helpers

setup() {
  make_env
  unset SYNCOPATED_DISTRO SYNCOPATED_DISTRO_FAMILY SYNCOPATED_OS_RELEASE
}
teardown() { cleanup_env; }

@test "detect_distro and detect_distro_family identify Fedora" {
  printf 'NAME="Fedora Linux"\nVERSION_ID=43\nID=fedora\nVERSION="43 (Rawhide)"\n' >"$T/os-release"
  SYNCOPATED_OS_RELEASE=$T/os-release run bash -c 'source "$1"; detect_distro; detect_distro_family' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "fedora" ]
  [ "${lines[1]}" = "redhat" ]
}

@test "detect_distro and detect_distro_family identify Rocky Linux" {
  printf 'NAME="Rocky Linux"\nVERSION_ID="9.4"\nID="rocky"\nID_LIKE="rhel centos fedora"\n' >"$T/os-release"
  SYNCOPATED_OS_RELEASE=$T/os-release run bash -c 'source "$1"; detect_distro; detect_distro_family' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "rocky" ]
  [ "${lines[1]}" = "redhat" ]
}

@test "detect_distro and detect_distro_family identify AlmaLinux" {
  printf 'NAME="AlmaLinux"\nVERSION_ID="9.4"\nID="almalinux"\nID_LIKE="rhel centos fedora"\n' >"$T/os-release"
  SYNCOPATED_OS_RELEASE=$T/os-release run bash -c 'source "$1"; detect_distro; detect_distro_family' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "almalinux" ]
  [ "${lines[1]}" = "redhat" ]
}

@test "detect_distro and detect_distro_family identify Arch Linux" {
  printf 'NAME="Arch Linux"\nID=arch\nID_LIKE=arch\n' >"$T/os-release"
  SYNCOPATED_OS_RELEASE=$T/os-release run bash -c 'source "$1"; detect_distro; detect_distro_family' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "arch" ]
  [ "${lines[1]}" = "arch" ]
}

@test "detect_distro and detect_distro_family identify Ubuntu" {
  printf 'NAME="Ubuntu"\nVERSION_ID="24.04"\nID=ubuntu\nID_LIKE=debian\n' >"$T/os-release"
  SYNCOPATED_OS_RELEASE=$T/os-release run bash -c 'source "$1"; detect_distro; detect_distro_family' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "ubuntu" ]
  [ "${lines[1]}" = "debian" ]
}

@test "detect_distro and detect_distro_family identify Debian" {
  printf 'NAME="Debian GNU/Linux"\nVERSION_ID="12"\nID=debian\n' >"$T/os-release"
  SYNCOPATED_OS_RELEASE=$T/os-release run bash -c 'source "$1"; detect_distro; detect_distro_family' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "debian" ]
  [ "${lines[1]}" = "debian" ]
}

@test "detect_distro and detect_distro_family handle unknown distribution" {
  printf 'NAME="CustomOS"\nVERSION_ID="1.0"\nID=customos\n' >"$T/os-release"
  SYNCOPATED_OS_RELEASE=$T/os-release run bash -c 'source "$1"; detect_distro; detect_distro_family' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "customos" ]
  [ "${lines[1]}" = "linux" ]
}

@test "detect_distro and detect_distro_family fallback to linux when os-release is missing" {
  SYNCOPATED_OS_RELEASE=$T/nonexistent run bash -c 'source "$1"; detect_distro; detect_distro_family' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "linux" ]
  [ "${lines[1]}" = "linux" ]
}

@test "SYNCOPATED_DISTRO override wins" {
  printf 'ID=fedora\n' >"$T/os-release"
  SYNCOPATED_OS_RELEASE=$T/os-release SYNCOPATED_DISTRO=customarch run bash -c 'source "$1"; detect_distro; detect_distro_family' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "customarch" ]
}

@test "SYNCOPATED_DISTRO_FAMILY override wins" {
  printf 'ID=fedora\n' >"$T/os-release"
  SYNCOPATED_OS_RELEASE=$T/os-release SYNCOPATED_DISTRO_FAMILY=bsd run bash -c 'source "$1"; detect_distro; detect_distro_family' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "${lines[1]}" = "bsd" ]
}

@test "banner includes distribution and desktop environment" {
  printf 'NAME="Fedora Linux"\nVERSION_ID=43\nID=fedora\n' >"$T/os-release"
  SYNCOPATED_OS_RELEASE=$T/os-release SYNCOPATED_DESKTOP=gnome run bash -c 'source "$1"; banner' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [[ $output == *"Fedora Linux 43"* ]]
  [[ $output == *"Desktop: gnome"* ]]
  [[ $output == *"Distro: fedora"* ]]
}
