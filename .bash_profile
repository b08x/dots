
[[ -s "$HOME/.profile" ]] && source "$HOME/.profile" # Load the default .profile

. "$HOME/.cargo/env"

[[ -s "$HOME/.local/bin" ]] && export PATH="$PATH:$HOME/.local/bin"

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
