# ensure dotfiles bin directory is loaded first
PATH="$HOME/.bin:$HOME/.local/bin:/usr/local/sbin:$PATH"

# Try loading ASDF from the regular home dir location
if [ -f "$HOME/.asdf/asdf.sh" ]; then
  . "$HOME/.asdf/asdf.sh"
elif which brew >/dev/null &&
  BREW_DIR="$(dirname `which brew`)/.." &&
  [ -f "$BREW_DIR/opt/asdf/asdf.sh" ]; then
  . "$BREW_DIR/opt/asdf/asdf.sh"
fi

# mkdir .git/safe in the root of repositories you trust
#PATH=".git/safe/../../bin:$PATH"
PATH="$PATH:$HOME/.cargo/bin"
PATH="$PATH:/opt/sonic-pi/bin"

#WARNING:  You don't have /home/b08x/.gem/ruby/2.7.0/bin in your PATH,
#	  gem executables will not run.
PATH="$PATH:$HOME/.gem/ruby/2.7.0/bin"
export -U PATH
