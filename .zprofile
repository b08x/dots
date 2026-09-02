export UU_ORDER="$UU_ORDER:~/.zprofile"

# Source ~/.profile for login shells (Kaizen: Standardized Work)
[[ -s "$HOME/.profile" ]] && source "$HOME/.profile"

# Added by `rbenv init` on Wed Sep  2 05:30:09 AM EDT 2026
eval "$(rbenv init - --no-rehash zsh)"
