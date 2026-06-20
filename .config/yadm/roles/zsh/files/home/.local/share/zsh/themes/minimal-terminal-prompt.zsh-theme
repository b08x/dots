# ------------------------------------------------------------------------------
#          FILE:  minimal-terminal-prompt.zsh-theme
#   DESCRIPTION:  oh-my-zsh theme file to show simple git status
#        AUTHOR:  Alicia Sykes (alicia@as93.net)
#       VERSION:  1.0.0
#    SCREENSHOT:  screenshot.gif
#          REPO:  https://github.com/Lissy93/minimal-terminal-prompt
#   DIRECT LINK:  https://raw.githubusercontent.com/Lissy93/minimal-terminal-prompt/master/minimal-terminal-prompt.zsh-theme
# ------------------------------------------------------------------------------



# color vars
eval col_gray='$FG[240]'
eval col_orange='$FG[202]'
eval col_pink='$FG[201]'
eval col_purple='$FG[093]'
eval col_red='$FG[124]'
eval col_yellow='$FG[011]'
eval col_hotpink='$FG[013]'
eval col_wine='$FG[001]'
eval col_random='$FG[088]'

HOSTNAME=$( cat /etc/hostname )

local return_code="%(?..%{$fg[red]%}%? ↵%{$reset_color%})"

if [ $UID -eq 0 ];
then
PROMPT='$col_red%n@%m%{$reset_color%} [$col_gray%~%{$reset_color%}]%  '
else


PROMPT='%{$col_yellow%}[%{$col_gray%}%m%{$col_yellow%}]%{$col_wine%}[$col_gray%~%{$col_wine%}]$(git_prompt_info)$col_gray%(?.%{$col_wine%}.%{$col_pink%})%{$reset_color%} '




fi
PROMPT2='%{$fg[red]%}\ %{$reset_color%}'
RPS1='${return_code}'

#${PR_LIGHT_BLUE}%{$reset_color%}$(git_prompt_info)$(git_prompt_status)${PR_BLUE})${PR_CYAN}${PR_HBAR}\

# right prompt
# if type "virtualenv_prompt_info" > /dev/null
# then
# 	RPROMPT='$(virtualenv_prompt_info)$col_gray%n@%m%{$reset_color%} [$(date +%H:%M)]%'
# else
# 	RPROMPT='$col_gray%n@%m%{$reset_color%} [$(date +%H:%M)]%%'
# fi

# git settings
ZSH_THEME_GIT_PROMPT_PREFIX="$col_purple($col_gray"
ZSH_THEME_GIT_PROMPT_CLEAN=""
ZSH_THEME_GIT_PROMPT_DIRTY="$col_pink+%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="$col_purple)%{$reset_color%}"
