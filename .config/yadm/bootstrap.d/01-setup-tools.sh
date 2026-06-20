#!/bin/bash
# =============================================================================
# YADM Bootstrap Step: Install Prerequisites (Ansible & System Core)
# =============================================================================
source "$HOME/.config/yadm/scripts/gum-helpers.sh"

# Initialize gum before using it
gum_init || { echo "Failed to initialize gum"; exit 1; }

# Show Field Note header for this step
fn_header "Prerequisites Setup"

# 1. Update/Install Ansible and dependencies via DNF
fn_step "Installing Ansible and dependencies..."
if ! command -v ansible-playbook >/dev/null 2>&1; then
    fn_info "Installing Ansible, git, python3-pip, python3-devel..."
    if sudo dnf install -y ansible git python3-pip python3-devel; then
        fn_success "Ansible and dependencies installed successfully!"
    else
        fn_error "Failed to install Ansible dependencies"
        exit 1
    fi
else
    fn_success "Ansible is already installed."
fi

sleep 1
clear
sleep 1

declare -A CARGO_CRATES=(
    ["bottom"]="btm"
    ["gping"]="gping"
    ["ripgrep_all"]="rga"
    ["sd"]="sd"
    ["choose"]="choose"
)

for crate in "${!CARGO_CRATES[@]}"; do
    cmd="${CARGO_CRATES[$crate]}"
    if ! command -v "$cmd" >/dev/null 2>&1 && [[ ! -x "$HOME/.cargo/bin/$cmd" ]]; then
        cargo install "$crate" || echo "unable to install $crate"
    fi
done

# 2. Install community collections if needed
fn_step "Verifying Ansible collections..."

CHOOSE_CMD="choose"
if ! command -v choose >/dev/null 2>&1 && [[ -x "$HOME/.cargo/bin/choose" ]]; then
    CHOOSE_CMD="$HOME/.cargo/bin/choose"
fi

if ansible-galaxy collection list 2>/dev/null | $CHOOSE_CMD 0 2>/dev/null | grep -q "posix" && \
   ansible-galaxy collection list 2>/dev/null | $CHOOSE_CMD 0 2>/dev/null | grep -q "general"; then
    fn_success "Ansible collections are already installed."
else
    fn_info "Installing Ansible collections via DNF..."
    if sudo dnf install -y ansible-collection-ansible-posix ansible-collection-community-general; then
        fn_success "Ansible collections installed/updated via DNF."
    else
        fn_error "Failed to install Ansible collections"
    fi
fi

echo ""
fn_success "Prerequisites bootstrap complete! Ready to run Ansible."
echo ""


