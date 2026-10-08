#!/usr/bin/env bash
# shellcheck disable=SC2034  # RC_* and palette variables are used by sourcing scripts
# syncopated-theme.sh: Syncopated first-boot palette and output helpers for
# yadm bootstrap. Source it; it defines functions and variables only.
#
# Overrides: SYNCOPATED_OS_RELEASE (os-release path),
# SYNCOPATED_NO_ANIM=1 (disable the typewriter delay).

[[ -n ${SYNCOPATED_THEME_LOADED:-} ]] && return 0
SYNCOPATED_THEME_LOADED=1

OS_RELEASE=${SYNCOPATED_OS_RELEASE:-/etc/os-release}

# Step return codes, shared with bootstrap.d scripts.
RC_OK=0
RC_FAILED=1
RC_SKIPPED=2

STEPS=()
declare -gA STEP_STATE=()

# Brand palette, sampled from the Syncopated logo. Each entry is
# (hex for gum and 24-bit terminals, 256-color index for other terminals).
VIOLET=('#7B4FE0' 98)
VIOLET_DIM=('#4B3A8C' 60)
VIOLET_LIGHT=('#A98BF0' 141)
EMBER=('#D2601A' 166)
EMBER_DIM=('#7A3A1C' 94)

# Theme gum's prompts with the palette. GUM_* values already set by the user win.
export GUM_CHOOSE_HEADER_FOREGROUND=${GUM_CHOOSE_HEADER_FOREGROUND:-${VIOLET_LIGHT[0]}}
export GUM_CHOOSE_CURSOR_FOREGROUND=${GUM_CHOOSE_CURSOR_FOREGROUND:-${EMBER[0]}}
export GUM_CHOOSE_SELECTED_FOREGROUND=${GUM_CHOOSE_SELECTED_FOREGROUND:-${EMBER[0]}}
export GUM_INPUT_HEADER_FOREGROUND=${GUM_INPUT_HEADER_FOREGROUND:-${VIOLET_LIGHT[0]}}
export GUM_INPUT_PROMPT_FOREGROUND=${GUM_INPUT_PROMPT_FOREGROUND:-${EMBER[0]}}
export GUM_INPUT_CURSOR_FOREGROUND=${GUM_INPUT_CURSOR_FOREGROUND:-${EMBER[0]}}

# Splash art (copied from syncopated-firstboot). Columns before ART_SPLIT are
# the mark; the rest is the wordmark. Glyphs in ART_DIM_GLYPHS take the dim tone.
ART_SPLIT=42
ART_DIM_GLYPHS=".'\`,:;^\"!Iil"
mapfile -t ART <<'ART'
                    Il
                 "+(tt)>.
               ,[ftfff//)I
              <tttt\1)/\/\<
           'i1tt/f[}_,_/\|\;
         ,_|tt////(_<~{\|||_
      ^<)tt//////\//\\\||((-   ..
  ':+)tt\|////\\\\||||(((()1: ,:.                                                                                                   .``                          ``.
`I<++i,">)\\\\\|||||((((()((_l"                                                                                                     ,))^                        ,)):
.     ;[\\\\\||||((((()))([<+{?;                 .^,^.     ``.   .``  .``  ^"`       .^"`.       '"^'     ``  ^"`.      `"^. ``   ``l));``'     .^,"'       `"^ ^)):
    ;{\\\\||||((((())))({+<]1{{{<              .+{}[{1+'  ^1)I   i)}. :))~]{))[,   l])11))-"  '<{)11)}>. "))+]{1)1~'  ![)1{}]))^ "111))111_   ,_}[][{-"  .<{)1{}-)):
  .+\\|||||(((((()))1)1->-11}}}[}I             ^))-l!<:   ^))I . i){. :))+`.`[)?  <)1I'.^+[~ .])?"'',])? "))?,'':[)? l))!''"?))^  `'I)):``.  "))}~<~}))^ _){:''"-)):
  '}|||||((((()))111)[<~}1}}}}[[[-              "i<_-[]I  ^))I   <){. :))`   +)?  [)_    ';" '))l    i)1 "))I    <)1 <)}    l)1'    :))`     l)1_<~<~>~^ })+    :)):
  `?((((((()))1111){~<]1{}}}[[[[]]"            ;}}iI!1)-  .[){i!~{){. ;))"   -)[  ;1)]>i+))+  i))_ii-))! "))1_ii?))i ^{)}>i_{))_.   :))-><"  .?)[iIi]_^  l))]>i+{)):
(ffrx/)()))1111{11->_{{}[[[[[]]]]]I             :~]]]+I.   `i+-_;i)}. "__`   !_>   'l_]]?<,    ^i-]]-!`  "))li?]?<,   '!-]]<`!__.   .>_---,    ;+][]+l'   "<?]?>,__^
?j)(j())11111{{1]<~[{[[[[[]]]]]???i                         `ii!![)1.                                    ,)):
"f)|/1)1111{{1}~>?{}[[[[]]]]????--+                         :????-_l                                     `__"
 {||)11{{{{}}_>_}}[[]]]]]????----__`
.}1{1{{{{}{1-<]}[]]]]]????----_____,
,[l<{{+-}}{1{}[?_]]]_~?-+,i-_>>__;<!
'.  ,:  I>'..;I. :~l. :l.  ,^  ;,  "
ART

# --- output ------------------------------------------------------------------

have_gum() {
  command -v gum >/dev/null 2>&1
}

# A broken gum earlier in PATH (for example a wrapper script) would swallow all
# styled output. Fall back to the packaged binary when it works.
if have_gum && ! gum --version >/dev/null 2>&1 && [[ -x /usr/bin/gum ]] && /usr/bin/gum --version >/dev/null 2>&1; then
  PATH=/usr/bin:$PATH
fi

# animating: true when output should be revealed character by character.
animating() {
  [[ -t 1 && -z ${SYNCOPATED_NO_ANIM:-} ]]
}

# typewriter: copy stdin to stdout one character at a time. Escape sequences
# are passed through without a delay. Plain copy when not animating.
typewriter() {
  if ! animating; then
    cat
    return
  fi
  local char in_esc=0
  while IFS= read -r -N1 char; do
    printf '%s' "$char"
    if ((in_esc)); then
      [[ $char == [a-zA-Z] ]] && in_esc=0
    elif [[ $char == $'\e' ]]; then
      in_esc=1
    else
      sleep 0.001
    fi
  done
}

# style COLOR LINE... : print lines in a foreground color (hex or 256-color).
style() {
  local color=$1
  shift
  if have_gum; then
    gum style --foreground "$color" -- "$@"
  else
    printf '%s\n' "$@"
  fi
}

# paint FD HEX INDEX TEXT : print one line to FD in a palette color through the
# typewriter. Plain text when gum is absent or FD is not a terminal.
paint() {
  local fd=$1 hex=$2 idx=$3 text
  shift 3
  text=$*
  {
    if have_gum && [[ -t $fd ]]; then
      printf '%s%s\e[0m\n' "$(fg "$hex" "$idx")" "$text" | typewriter
    else
      printf '%s\n' "$text"
    fi
  } >&"$fd"
}

# Syslog identifier for systemd-cat (customizable via SYNCOPATED_LOG_IDENTIFIER)
BOOTSTRAP_LOG_IDENTIFIER=${SYNCOPATED_LOG_IDENTIFIER:-yadm-bootstrap}

have_systemd_cat() {
  command -v systemd-cat >/dev/null 2>&1
}

# systemd_cat_log PRIORITY [MESSAGE...] : log to systemd journal via systemd-cat.
# Supports both message arguments and standard input piping.
systemd_cat_log() {
  local priority=${1:-info}
  shift
  have_systemd_cat || return 0
  local prefix=""
  [[ -n ${SYNCOPATED_STEP:-} ]] && prefix="[${SYNCOPATED_STEP}] "
  if (($# > 0)); then
    printf '%s%s\n' "$prefix" "$*" | systemd-cat -t "$BOOTSTRAP_LOG_IDENTIFIER" -p "$priority" 2>/dev/null || true
  else
    if [[ -n $prefix ]]; then
      sed "s/^/$prefix/" | systemd-cat -t "$BOOTSTRAP_LOG_IDENTIFIER" -p "$priority" 2>/dev/null || true
    else
      systemd-cat -t "$BOOTSTRAP_LOG_IDENTIFIER" -p "$priority" 2>/dev/null || true
    fi
  fi
}

info() {
  systemd_cat_log info "➜ $*"
  paint 1 "${VIOLET_LIGHT[@]}" "➜ $*"
}

ok() {
  systemd_cat_log notice "✓ $*"
  paint 1 "${EMBER[@]}" "✓ $*"
}

warn() {
  systemd_cat_log warning "! $*"
  paint 2 '#E0A030' 214 "! $*"
}

err() {
  systemd_cat_log err "✗ $*"
  paint 2 '#D03030' 160 "✗ $*"
}

# fg HEX INDEX : print the SGR sequence for a foreground color. Uses 24-bit
# color when the terminal reports it in COLORTERM, else the 256-color index.
fg() {
  local hex=${1#\#}
  if [[ ${COLORTERM:-} == truecolor || ${COLORTERM:-} == 24bit ]]; then
    printf '\e[38;2;%d;%d;%dm' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
  else
    printf '\e[38;5;%sm' "$2"
  fi
}

# os_field KEY : print the value of KEY from os-release, without quotes.
os_field() {
  local key=$1 line value
  [[ -r $OS_RELEASE ]] || return 1
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line == "$key="* ]] || continue
    value=${line#*=}
    value=${value#[\"\']}
    value=${value%[\"\']}
    printf '%s\n' "$value"
    return 0
  done <"$OS_RELEASE"
  return 1
}

os_label() {
  local name version
  name=$(os_field NAME) || name=Linux
  version=$(os_field VERSION_ID) || version=
  printf '%s\n' "$name${version:+ $version}"
}

# paint_art WIDTH : fill ART_PAINTED with the ART lines cut to WIDTH columns.
# The palette is swapped relative to first-boot: the mark is ember and the
# wordmark is violet, each glyph in the dim or full tone.
paint_art() {
  local width=$1 row col line ch tone prev out
  local -A seq=(
    [mark]=$(fg "${EMBER[@]}") [mark_dim]=$(fg "${EMBER_DIM[@]}")
    [word]=$(fg "${VIOLET[@]}") [word_dim]=$(fg "${VIOLET_DIM[@]}")
  )
  ART_PAINTED=()
  for ((row = 0; row < ${#ART[@]}; row++)); do
    line=${ART[row]:0:width} out='' prev=''
    for ((col = 0; col < ${#line}; col++)); do
      ch=${line:col:1}
      if [[ $ch == ' ' ]]; then
        out+=' '
        continue
      fi
      # The logo draws "{1{}" on the mark's second-to-last row in the other
      # brand color; here that accent is violet.
      if ((col < ART_SPLIT)) && ! ((row == 19 && col >= 10 && col <= 13)); then
        tone=mark
      else
        tone=word
      fi
      [[ $ART_DIM_GLYPHS == *"$ch"* ]] && tone+=_dim
      [[ $tone == "$prev" ]] || out+=${seq[$tone]}
      prev=$tone
      out+=$ch
    done
    ART_PAINTED+=("$out"$'\e[0m')
  done
}

# logo : print the art, then the caption. Uncolored art when stdout is not a
# terminal; the mark only when the terminal is narrower than the art.
logo() {
  local caption='user configuration · yadm bootstrap' width=0 cols line
  if [[ ! -t 1 ]]; then
    printf '%s\n' "${ART[@]}"
    printf '%s\n' "$caption"
    return 0
  fi
  cols=$(tput cols 2>/dev/null || echo 80)
  for line in "${ART[@]}"; do
    ((${#line} > width)) && width=${#line}
  done
  ((width > cols)) && width=$((ART_SPLIT < cols ? ART_SPLIT : cols))
  paint_art "$width"
  printf '%s\n' "${ART_PAINTED[@]}"
  printf '\n%s%s\e[0m\n' "$(fg "${VIOLET_LIGHT[@]}")" "$caption"
}

banner() {
  local label
  label=$(os_label)
  if have_gum; then
    gum style --border double --border-foreground "${EMBER[0]}" --foreground "${VIOLET[0]}" \
      --align center --width 60 --padding "1 2" \
      "SYNCOPATED" "$label" "User configuration"
  else
    printf '%s\n' \
      "============================================================" \
      "  SYNCOPATED  |  $label  |  User configuration" \
      "============================================================"
  fi
}

# splash : full-screen splash like first-boot: the art centered, revealed row
# by row, then held with a pulsing "press enter to begin" until Enter. Falls
# back to logo when stdin or stdout is not a terminal. SYNCOPATED_NO_ANIM=1
# skips the reveal delay and the wait.
splash() {
  if [[ ! -t 0 || ! -t 1 ]] || ! tput cup 0 0 >/dev/null 2>&1; then
    logo
    return 0
  fi
  local rows cols width=0 height=${#ART[@]} line row top left prompt='press enter to begin' prow pcol lit=1 rc
  rows=$(tput lines)
  cols=$(tput cols)
  for line in "${ART[@]}"; do
    ((${#line} > width)) && width=${#line}
  done
  ((width > cols)) && width=$((ART_SPLIT < cols ? ART_SPLIT : cols))
  paint_art "$width"

  top=$(((rows - height - 2) / 2))
  ((top < 0)) && top=0
  left=$(((cols - width) / 2))
  prow=$((top + height + 2 < rows ? top + height + 2 : rows - 1))
  pcol=$(((cols - ${#prompt}) / 2))
  ((pcol < 0)) && pcol=0

  clear
  tput civis 2>/dev/null
  for ((row = 0; row < height; row++)); do
    tput cup $((top + row)) "$left"
    printf '%s' "${ART_PAINTED[row]}"
    [[ -n ${SYNCOPATED_NO_ANIM:-} ]] || sleep 0.03
  done
  if [[ -z ${SYNCOPATED_NO_ANIM:-} ]]; then
    while :; do
      tput cup "$prow" "$pcol"
      if ((lit)); then fg "${EMBER[@]}"; else fg "${EMBER_DIM[@]}"; fi
      printf '%s\e[0m' "$prompt"
      lit=$((1 - lit))
      read -r -s -t 0.8 _
      rc=$?
      # 0 = Enter, >128 = timeout (pulse again), anything else = EOF/error.
      ((rc > 128)) || break
    done
  fi
  clear
  tput cnorm 2>/dev/null
}

# draw_steps : print STEPS with the state recorded in STEP_STATE.
draw_steps() {
  local step state icon lines=()
  for step in "${STEPS[@]}"; do
    state=${STEP_STATE[$step]:-pending}
    case $state in
      ok) icon='✓' ;;
      failed) icon='✗' ;;
      skipped) icon='-' ;;
      *) icon='·' ;;
    esac
    lines+=("$icon $step ($state)")
  done
  if have_gum; then
    gum style --border rounded --border-foreground "${VIOLET_DIM[0]}" --padding "0 2" -- "${lines[@]}"
  else
    printf '  %s\n' "${lines[@]}"
  fi
}

# choose HEADER OPTION... : print the selected option. Fails on cancel/EOF.
choose() {
  local header=$1 reply opt i
  shift
  if have_gum; then
    gum choose --header "$header" "$@"
    return
  fi
  printf '%s\n' "$header" >&2
  for ((i = 1; i <= $#; i++)); do
    printf '  %d) %s\n' "$i" "${!i}" >&2
  done
  while :; do
    read -r -p "Choose [1-$#]: " reply || return 1
    if [[ $reply =~ ^[0-9]+$ ]] && ((reply >= 1 && reply <= $#)); then
      printf '%s\n' "${!reply}"
      return 0
    fi
    for opt in "$@"; do
      [[ $reply == "$opt" ]] && {
        printf '%s\n' "$opt"
        return 0
      }
    done
    printf 'Enter a number from 1 to %d.\n' "$#" >&2
  done
}

# --- labels ------------------------------------------------------------------

# capitalize WORD : uppercase the first letter, leave the rest as is.
capitalize() {
  printf '%s%s\n' "$(printf '%s' "${1:0:1}" | tr '[:lower:]' '[:upper:]')" "${1:1}"
}

# step_label NAME : human-readable step name. 20-cargo.sh -> Cargo,
# preflight -> Preflight, 80-install-user-flatpaks.sh -> Install user flatpaks.
step_label() {
  local name=${1##*/}
  name=${name%.sh}
  name=${name#[0-9][0-9]-}
  name=${name//[-_]/ }
  capitalize "$name"
}

# item_label ID : human-readable item name. org.mozilla.firefox -> Firefox,
# rubocop -> Rubocop. Dotted ids keep their last segment as written.
item_label() {
  local id=$1
  if [[ $id == *.* ]]; then
    printf '%s\n' "$(capitalize "${id##*.}")"
  else
    capitalize "$id"
  fi
}

# --- menus and spinners ------------------------------------------------------

# choose_many HEADER OPTION... : print the selected options, one per line, with
# every option preselected. Fails on cancel/EOF. The plain prompt takes
# numbers separated by commas or spaces; an empty line keeps everything.
choose_many() {
  local header=$1 reply n i selected=()
  shift
  if have_gum; then
    local IFS=,
    gum choose --no-limit --ordered --header "$header" --selected "$*" -- "$@"
    return
  fi
  printf '%s\n' "$header" >&2
  for ((i = 1; i <= $#; i++)); do
    printf '  %d) %s\n' "$i" "${!i}" >&2
  done
  while :; do
    read -r -p "Choose [numbers, empty for all]: " reply || return 1
    reply=${reply//,/ }
    if [[ -z ${reply// /} ]]; then
      printf '%s\n' "$@"
      return 0
    fi
    selected=()
    for n in $reply; do
      if [[ $n =~ ^[0-9]+$ ]] && ((n >= 1 && n <= $#)); then
        selected+=("${!n}")
      else
        printf 'Enter numbers from 1 to %d.\n' "$#" >&2
        continue 2
      fi
    done
    printf '%s\n' "${selected[@]}"
    return 0
  done
}

# spinner_ok : true when a gum spinner can be shown on this terminal.
spinner_ok() {
  have_gum && { [[ -t 1 ]] || [[ -n ${SYNCOPATED_FORCE_INTERACTIVE:-} ]]; }
}

# drain_tty_input : discard unconsumed terminal responses (such as DECRQM
# mode 2026/2027 and kitty keyboard queries sent by gum 2.x) from the
# terminal input buffer so they do not leak into stdout or future prompts.
drain_tty_input() {
  local prev_ttin
  prev_ttin=$(trap -p SIGTTIN)
  trap '' SIGTTIN 2>/dev/null
  if ( : </dev/tty ) 2>/dev/null; then
    while IFS= read -rs -t 0.05 -N 1000 -u 3 _; do :; done 3</dev/tty 2>/dev/null
  elif [[ -t 0 ]]; then
    while IFS= read -rs -t 0.05 -N 1000 _; do :; done 2>/dev/null
  fi
  if [[ -n $prev_ttin ]]; then
    eval "$prev_ttin"
  else
    trap - SIGTTIN 2>/dev/null
  fi
}

# run_item LABEL CMD... : run one install under a spinner titled with LABEL.
# Output goes to a temp file, is appended to the log, logged to systemd-cat,
# and is printed only when the command fails. Returns the command's exit status.
run_item() {
  local label=$1 out rc log=${LOG_FILE:-$HOME/.bootstrap.log}
  shift
  out=$(mktemp) || return 1
  if spinner_ok; then
    systemd_cat_log info "Installing $label"
    # gum starts a new process, so a shell function must be exported first.
    [[ $(type -t "$1") == function ]] && export -f "${1?}"

    local saved_stty="" tty_device=""
    if [[ -t 0 ]]; then
      saved_stty=$(stty -g 2>/dev/null)
    elif [[ -r /dev/tty ]]; then
      saved_stty=$(stty -g </dev/tty 2>/dev/null)
      tty_device="/dev/tty"
    fi

    if [[ -n $saved_stty ]]; then
      if [[ -n $tty_device ]]; then
        stty -echo <"$tty_device" 2>/dev/null
      else
        stty -echo 2>/dev/null
      fi
    fi

    # Disable SHOW_OUTPUT so gum spin does not attach or stream command output to terminal.
    # shellcheck disable=SC2016  # $1 and $@ belong to the child shell
    GUM_SPIN_SHOW_OUTPUT=false gum spin --show-output=false --spinner dot --title "Installing $label" -- \
      bash -c 'out=$1; shift; "$@" >"$out" 2>&1 </dev/null' _ "$out" "$@"
    rc=$?

    drain_tty_input

    if [[ -n $saved_stty ]]; then
      if [[ -n $tty_device ]]; then
        stty "$saved_stty" <"$tty_device" 2>/dev/null
      else
        stty "$saved_stty" 2>/dev/null
      fi
    fi
  else
    info "Installing $label"
    "$@" >"$out" 2>&1 </dev/null
    rc=$?
  fi
  if [[ -s $out ]]; then
    if ((rc == 0)); then
      systemd_cat_log info <"$out"
    else
      systemd_cat_log err <"$out"
    fi
  fi
  if ((rc == 0)); then
    systemd_cat_log notice "$label (exit $rc)"
  else
    systemd_cat_log err "$label (exit $rc)"
  fi
  {
    printf '[%s] %s (exit %d)\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$label" "$rc"
    cat "$out"
  } >>"$log" 2>/dev/null
  if ((rc == 0)); then
    ok "$label"
  else
    err "$label"
    sed 's/^/    /' "$out" >&2
  fi
  rm -f "$out"
  return "$rc"
}
