#!/usr/bin/env bash
# notebook-bootstrap.sh - Bootstrap an Obsidian vault with standard plugins
# Uses `obsidian` CLI to install and enable plugins, and `gum` for pretty UI.

# Bash Defensive Patterns
set -euo pipefail
IFS=$'\n\t'

# Source gum helpers
export GUM_HELPERS_NO_TRAP=1
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/gum-helpers.sh"

USE_FLATPAK=true
INIT_GIT=true

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

# Usage information
usage() {
    echo "Usage: ./notebook-bootstrap.sh [OPTIONS]"
    echo "Options:"
    echo "  -f, --flatpak    Install and launch Obsidian via Flatpak before configuring"
    echo "  -g, --git        Initialize a Git repository and default .gitignore"
    exit 0
}

# Create a default .gitignore for an Obsidian vault
create_gitignore() {
    if [[ -f ".gitignore" ]]; then
        gum log --level info ".gitignore already exists. Skipping creation."
        return 0
    fi
    
    gum log --level info "Creating default .gitignore..."
    
    local ignores=(
        "# Obsidian specific"
        ".obsidian/workspace"
        ".obsidian/workspace.json"
        ".obsidian/workspace-mobile.json"
        ".trash/"
        ""
        "# Plugin Secrets & API Keys"
        ".obsidian/plugins/ai-tagger-universe/data.json"
        ".obsidian/plugins/canvas-llm/data.json"
        ".obsidian/plugins/mesh-ai/data.json"
        ".obsidian/plugins/notemd/data.json"
        ".obsidian/plugins/obsidian-audio-notes/data.json"
        ".obsidian/plugins/obsidian-local-rest-api/data.json"
        ".obsidian/plugins/proofreader/data.json"
        ".obsidian/plugins/smart-composer/data.json"
        ".obsidian/plugins/wayback-archiver/data.json"
        ".obsidian/plugins/text-extractor/cache/"
        ""
        "# OS generated files"
        ".DS_Store"
        "Thumbs.db"
    )
    
    printf "%s\n" "${ignores[@]}" > .gitignore
}

# Initialize a git repository safely
init_git() {
    if [[ ! -d ".git" ]]; then
        if command -v git &> /dev/null; then
            gum log --level info "Initializing Git repository in the vault root..."
            git init > /dev/null 2>&1
            create_gitignore
        else
            gum log --level warn "Git is not installed. Skipping repository initialization."
        fi
    else
        gum log --level info "Git repository already initialized."
        create_gitignore
    fi
}

# Ensure prerequisites are met
check_prerequisites() {
    if ! command -v gum &> /dev/null; then
        echo "gum could not be found. Please install it first (e.g., sudo apt install gum / brew install gum)."
        exit 1
    fi
}

prompt_vault_location() {
    local default_vault="${HOME}/Notebook"
    gum log --level info "Please specify the Obsidian vault location."
    
    local vault_input
    if ! vault_input=$(gum input --prompt "Vault location [${default_vault}]: " --placeholder "${default_vault}"); then
        gum log --level error "Vault location input cancelled."
        exit 1
    fi
    
    if [[ -z "${vault_input}" ]]; then
        VAULT_DIR="${default_vault}"
    else
        VAULT_DIR="${vault_input/#\~/$HOME}"
    fi
    
    gum log --level info "Using vault location: ${VAULT_DIR}"
    
    if [[ ! -d "${VAULT_DIR}" ]]; then
        gum log --level info "Directory does not exist. Creating ${VAULT_DIR}..."
        mkdir -p "${VAULT_DIR}"
    fi
    
    cd "${VAULT_DIR}" || {
        gum log --level error "Failed to change directory to ${VAULT_DIR}"
        exit 1
    }
    
    if [[ ! -d ".obsidian/plugins" ]]; then
        gum log --level info "Creating .obsidian/plugins directory..."
        mkdir -p ".obsidian/plugins"
    fi
}

# Handle Flatpak launch/install logic
setup_flatpak() {
    gum log --level info "Flatpak mode enabled. Checking Obsidian installation..."
    
    if ! command -v flatpak &> /dev/null; then
        gum log --level error "flatpak command not found. Please install Flatpak first."
        exit 1
    fi
    
    if ! flatpak list | grep -q md.obsidian.Obsidian; then
        gum log --level info "Installing Obsidian via Flatpak..."
        flatpak install -y flathub md.obsidian.Obsidian
    fi
    
    # Check if Obsidian is running, if not launch it
    if ! pgrep -f "md.obsidian.Obsidian" &> /dev/null && ! pgrep -f "obsidian" &> /dev/null; then
        gum log --level info "Launching Obsidian via Flatpak in the background..."
        # redirect output to /dev/null so it doesn't clutter the terminal
        flatpak run md.obsidian.Obsidian > /dev/null 2>&1 &
        # Give it a few seconds to start up and expose the CLI API
        gum spin --spinner dot --title "Waiting for Obsidian to initialize..." -- sleep 8
    else
        gum log --level info "Obsidian is already running."
    fi
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --flatpak|-f) USE_FLATPAK=true ;;
        --git|-g) INIT_GIT=true ;;
        -h|--help) usage ;;
        *) gum log --level error "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

check_prerequisites
prompt_vault_location

slide_transition
section_header "Git Initialization"
# Setup Git if requested (do this before launching Obsidian)
if [[ "$INIT_GIT" == true ]]; then
    init_git
fi

slide_transition
section_header "Obsidian Flatpak Setup"
if [[ "$USE_FLATPAK" == true ]]; then
    setup_flatpak
fi

slide_transition
section_header "Obsidian Plugins Configuration"
# Ensure obsidian CLI is installed
if ! command -v obsidian &> /dev/null; then
    gum log --level error "obsidian CLI could not be found."
    exit 1
fi

PLUGINS=(
    "advanced-merger"
    "obsidian-auto-link-title"
    "obsidian-chat-view"
    "cmdr"
    "mermaid-popup"
    "editing-toolbar"
    "folder-notes"
    "image-converter"
    "json-table"
    "obsidian-link-converter"
    "obsidian-linter"
    "obsidian-markdown-formatting-assistant-plugin"
    "markdown-table-editor"
    "mermaid-tools"
    "multi-properties"
    "note-refactor-obsidian"
    "obsidian-plantuml"
    "recent-files-obsidian"
    "regex-replace"
    "obsidian-shellcommands"
    "obsidian-textgenerator-plugin"
    "hide-folders"
    "liquid-templates"
    "obsidian-style-settings"
    "links"
    "obsidian-image-layouts"
    "frontmatter-markdown-links"
    "advanced-canvas"
    "obsidian-image-toolkit"
    "scholar"
    "better-export-pdf"
    "recent-notes"
    "edge-tts"
    "attachment-management"
    "consistent-attachments-and-links"
    "note-archiver"
    "obsidian-mindmap-nextgen"
    "obsidian-custom-attachment-location"
    "quick-tagger"
    "notes-merger"
    "merge-notes"
    "break-page"
    "obsidian-enhancing-export"
    "obsidian-git"
    "janitor"
    "obsidian-csv-table"
    "pretty-properties"
    "iconic"
    "obsidian-icon-folder"
    "task-list-kanban"
    "pdf-plus"
    "obsidian42-brat"
    "obsidian-local-rest-api"
    "canvas-link-optimizer"
    "foldercanvas"
    "canvas2document"
    "enhanced-canvas"
    "similar-notes"
    "dataview"
    "metadata-extractor"
    "omnisearch"
    "related-notes-by-tag"
    "semantic-canvas"
    "bulk-exporter"
    "ai-tagger-universe"
    "text-extractor"
    "realclaudian"
    "gemini-scribe"
)

TOTAL=${#PLUGINS[@]}
CURRENT=0

gum style --border normal --margin "1" --padding "1 2" --border-foreground 212 "Bootstrapping Obsidian Vault" "Vault: $(pwd)"

for plugin in "${PLUGINS[@]}"; do
    CURRENT=$((CURRENT + 1))
    if [[ -d ".obsidian/plugins/$plugin" ]]; then
        gum log --level info "Skipping: $plugin (already installed) [$CURRENT/$TOTAL]"
    else
        # obsidian CLI output is swallowed by gum spin unless it fails
        if gum spin --spinner dot --title "Installing: $plugin [$CURRENT/$TOTAL]" -- obsidian plugin:install id="$plugin" enable; then
            gum log --level info "Successfully installed and enabled $plugin."
        else
            gum log --level error "Failed to install $plugin."
        fi
    fi
done

gum log --level info "Disabled sync plugin"
obsidian plugin:disable id="sync" || true

gum style --foreground 212 "Bootstrap complete!"

clear
