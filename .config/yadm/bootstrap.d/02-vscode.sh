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
  'arcticicestudio.nord-visual-studio-code'
  'atishay-jain.all-autocomplete'
  'bierner.markdown-emoji'
  'boonboonsiri.gemini-autocomplete'
  'castwide.solargraph'
  'codium.codium'
  'davidanson.vscode-markdownlint'
  'devzstudio.emoji-snippets'
  'docker.docker'
  'donjayamanne.githistory'
  'dotiful.dotfiles-syntax-highlighting'
  'dotjoshjohnson.xml'
  'dracula-theme.theme-dracula'
  'eliverlara.andromeda'
  'esbenp.prettier-vscode'
  'foxundermoon.shell-format'
  'ginfuru.ginfuru-vscode-jekyll-syntax'
  'github.github-vscode-theme'
  'github.vscode-github-actions'
  'gitlab.gitlab-workflow'
  'google.geminicodeassist'
  'henoc.svgeditor'
  'hunnble.treetop'
  'icbd.gitlab-developers-snippets'
  'jeff-hykin.better-dockerfile-syntax'
  'jeffersonlicet.snipped'
  'kevinrose.vsc-python-indent'
  'liviuschera.noctis'
  'm0x2a.jekyll-helper'
  'monish.regexsnippets'
  'ms-azuretools.vscode-containers'
  'ms-azuretools.vscode-docker'
  'ms-python.autopep8'
  'ms-python.debugpy'
  'ms-python.python'
  'ms-python.vscode-pylance'
  'ms-vscode.cmake-tools'
  'ms-vscode.cpptools'
  'ms-vscode.cpptools-extension-pack'
  'ms-vscode.cpptools-themes'
  'ms-vscode.makefile-tools'
  'onatm.open-in-new-window'
  'redhat.ansible'
  'redhat.vscode-yaml'
  'rooveterinaryinc.roo-cline'
  'samuelcolvin.jinjahtml'
  'shopify.ruby-lsp'
  'sissel.shopify-liquid'
  'sublayer.sublayer-blueprints'
  'teabyii.ayu'
  'tomoki1207.pdf'
  'vsls-contrib.gistfs'
  'wesbos.theme-cobalt2'
  'wware.snippet-creator'
  'wware.snippets-explorer'
  'wyattferguson.jinja2-snippet-kit'
  'yzane.markdown-pdf'
  'yzhang.markdown-all-in-one'
  'zhuangtongfa.material-theme'
)

code --install-extension "${EXTENSIONS[@]}"

wipe

gum_green "extensions installed!"

sleep 1