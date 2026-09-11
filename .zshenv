export UU_ORDER="$UU_ORDER:~/.zshenv"

if [ -x "$(command -v most)" ]; then
PAGER=most
fi

export WORKSPACE="$HOME/Workspace"
export ARCHIVE="$HOME/Archive"
export DOCUMENTS="$HOME/Documents"
export SCREENSHOTS="$HOME/Screenshots"
export SCREENCASTS="$HOME/Screencasts"


[[ -f ~/.zshenv.local ]] && source ~/.zshenv.local

[[ -f ~/.env ]] && source ~/.env

[[ -f ~/.cargo/env ]] && source ~/.cargo/env

# export YDOTOOL_SOCKET="/tmp/.ydotool_socket"

#export PATH="$HOME/.local/bin:$HOME/Tools/bin:$PATH"

export RESTIC_REPO="/mnt/ninjabot/backup00/b08x"

export GRAPHIFY_OPENAI_MODEL="deepseek/deepseek-v4-flash-0731"

export OPENAI_MODEL="deepseek/deepseek-v4-flash-0731"
export OPENAI_BASE_URL="https://openrouter.ai/api/v1"

export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"
