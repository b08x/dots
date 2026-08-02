#!/usr/bin/env bash
# =============================================================================
# YADM Bootstrap Step 02: User-Space Flatpak Application Setup (Layer 2)
# =============================================================================
set -e

GUM=$(command -v gum || true)

function banner() {
    if [ -n "$GUM" ]; then
        $GUM style \
            --foreground 212 --border-foreground 212 --border double \
            --align center --width 60 --padding "1 2" \
            "SYNCOPATED WORKSTATION" "Flatpak User Application Setup"
    else
        echo "============================================================"
        echo "   SYNCOPATED WORKSTATION - Flatpak User Setup          "
        echo "============================================================"
    fi
}

function status_msg() {
    local msg="$1"
    if [ -n "$GUM" ]; then
        $GUM style --foreground 123 "➜ $msg"
    else
        echo "➜ $msg"
    fi
}

function success_msg() {
    local msg="$1"
    if [ -n "$GUM" ]; then
        $GUM style --foreground 46 "✓ $msg"
    else
        echo "✓ $msg"
    fi
}

clear || true
banner
echo ""

if ! command -v flatpak >/dev/null 2>&1; then
    echo "Warning: flatpak binary not found on this system. Skipping application setup."
    exit 0
fi

# 1. Curated list of user GUI / media / productivity apps
FLATPAK_APPS=(
    "md.obsidian.Obsidian"
    "io.typora.Typora"
    "org.audacityteam.Audacity"
    "org.freac.freac"
    "org.pipewire.Helvum"
    "io.gitlab.theevilskeleton.Upscaler"
    "io.github.ltiber.Pwall"
    "io.github.bhack.mini-eq"
    "org.nomacs.ImageLounge"
    "io.podman_desktop.PodmanDesktop"
    "io.dbeaver.DBeaverCommunity"
    "com.github.tchx84.Flatseal"
    "org.gnome.Extensions"
    "io.github.vikdevelop.SaveDesktop"
    "com.saivert.pwvucontrol"
    "com.mattjakeman.ExtensionManager"
    "page.tesk.Refine"
    "com.discordapp.Discord"
)

if [ ${#FLATPAK_APPS[@]} -gt 0 ]; then
    status_msg "Enabling Flathub remote in user scope (~/.local/share/flatpak)..."
    if [ -n "$GUM" ]; then
        $GUM spin --spinner dot --title "Enabling Flathub (--user)..." -- flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    else
        flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    fi

    status_msg "Installing component Flatpaks into user space..."
    for app in "${FLATPAK_APPS[@]}"; do
        if [ -n "$GUM" ]; then
            $GUM spin --spinner pulse --title "Installing $app (--user)..." -- flatpak install --user -y flathub "$app" || echo "Warning: Failed to install $app"
        else
            echo "Installing $app (--user)..."
            flatpak install --user -y flathub "$app" || echo "Warning: Failed to install $app"
        fi
    done
    success_msg "User-space Flatpak application setup complete!"
fi
echo ""
