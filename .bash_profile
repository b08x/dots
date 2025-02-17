
[[ -s "$HOME/.profile" ]] && source "$HOME/.profile" # Load the default .profile

. "$HOME/.cargo/env"

[[ -s "$HOME/.local/bin" ]] && export PATH="$PATH:$HOME/.local/bin"

[[ -s "$HOME/go/bin" ]] && export PATH="$PATH:$HOME/go/bin"


[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
