#!/usr/bin/env bash

# set a trap to exit with CTRL+C
ctrl_c() {
        echo "** End."
        sleep 1
}

trap ctrl_c INT SIGINT SIGTERM ERR EXIT

# --- Wipe Screen Function ---
wipe() {
  tput -S <<!
clear
cup 1
!
}

source $HOME/.config/yadm/bootstrap.d/gum_wrapper.sh

# Now you can use the gum functions
gum_init # Initialize gum (download if not present)

gum_title "vscode extensions"
gum_info "Install VSCode Extensions."

sleep 2

EXTENSIONS=(
  'ahmadawais.shades-of-purple'
  'anx450z.rubocop-runner'
  'arcticicestudio.nord-visual-studio-code'
  'atishay-jain.all-autocomplete'
  'bierner.markdown-emoji'
  'boonboonsiri.gemini-autocomplete'
  'castwide.solargraph'
  'codium.codium'
  'davidanson.vscode-markdownlint'
  'desislavarashev.ollama-commit'
  'devzstudio.emoji-snippets'
  'dinethsiriwardana.send-to-firebase'
  'docker.docker'
  'donjayamanne.githistory'
  'dotiful.dotfiles-syntax-highlighting'
  'dotjoshjohnson.xml'
  'dracula-theme.theme-dracula'
  'eliverlara.andromeda'
  'esbenp.prettier-vscode'
  'foxundermoon.shell-format'
  'ginfuru.ginfuru-vscode-jekyll-syntax'
  'github.copilot-chat'
  'github.copilot'
  'github.github-vscode-theme'
  'github.vscode-github-actions'
  'gitlab.gitlab-workflow'
  'gnana997.ollama-dev-companion'
  'google.geminicodeassist'
  'henoc.svgeditor'
  'hunnble.treetop'
  'icbd.gitlab-developers-snippets'
  'jeff-hykin.better-dockerfile-syntax'
  'jeffersonlicet.snipped'
  'kevinrose.vsc-python-indent'
  'liviuschera.noctis'
  'm0x2a.jekyll-helper'
  'mechatroner.rainbow-csv'
  'monish.regexsnippets'
  'mrmlnc.vscode-scss'
  'ms-azuretools.vscode-containers'
  'ms-azuretools.vscode-docker'
  'ms-python.autopep8'
  'ms-python.debugpy'
  'ms-python.python'
  'ms-python.vscode-pylance'
  'ms-vscode-remote.remote-containers'
  'ms-vscode.cmake-tools'
  'ms-vscode.cpptools-extension-pack'
  'ms-vscode.cpptools-themes'
  'ms-vscode.cpptools'
  'ms-vscode.makefile-tools'
  'onatm.open-in-new-window'
  'redhat.ansible'
  'redhat.vscode-yaml'
  'rooveterinaryinc.roo-cline'
  'rubocop.vscode-rubocop'
  'ruslan-cybersec.ollama-code-fixer'
  'samuelcolvin.jinjahtml'
  'shellomo.enhanced-toml'
  'shopify.ruby-lsp'
  'sibiraj-s.vscode-scss-formatter'
  'sissel.shopify-liquid'
  'sublayer.sublayer-blueprints'
  'teabyii.ayu'
  'technovangelist.ollamamodelfile'
  'tomoki1207.pdf'
  'vsls-contrib.gistfs'
  'warm3snow.vscode-ollama-modelfile'
  'wesbos.theme-cobalt2'
  'wware.snippet-creator'
  'wware.snippets-explorer'
  'wyattferguson.jinja2-snippet-kit'
  'yzane.markdown-pdf'
  'yzhang.markdown-all-in-one'
  'zhuangtongfa.material-theme'
)

for ext in "${EXTENSIONS[@]}"; do
  code --install-extension "$ext" || continue
done

wipe

gum_green "extensions installed!"

sleep 1