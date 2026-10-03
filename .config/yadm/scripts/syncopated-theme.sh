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
    gum style --foreground "$color" "$@"
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

info() { paint 1 "${VIOLET_LIGHT[@]}" "➜ $*"; }
ok() { paint 1 "${EMBER[@]}" "✓ $*"; }
warn() { paint 2 '#E0A030' 214 "! $*"; }
err() { paint 2 '#D03030' 160 "✗ $*"; }

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
    gum style --border rounded --border-foreground "${VIOLET_DIM[0]}" --padding "0 2" "${lines[@]}"
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
