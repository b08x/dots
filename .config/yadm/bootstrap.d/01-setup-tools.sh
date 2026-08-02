#!/usr/bin/env bash
# =============================================================================
# YADM Bootstrap Step 01: Declarative User-Space CLI Provisioning (Layer 2)
# =============================================================================
set -e

# Source rich TUI helpers if available
if [ -f "$HOME/.config/yadm/scripts/gum-helpers.sh" ]; then
    source "$HOME/.config/yadm/scripts/gum-helpers.sh"
    gum_init || true
else
    # Fallback output decorators if gum-helpers is missing
    function fn_header() { echo "=== $1 ==="; }
    function fn_step() { echo "➜ $1"; }
    function fn_info() { echo "  i $1"; }
    function fn_success() { echo "✓ $1"; }
    function fn_error() { echo "✗ $1" >&2; }
fi

fn_header "Layer 2 Workstation Tools Setup"

# 1. Ensure 'uv' is present for Python tool isolation without sudo
fn_step "Checking Python virtualenv manager (uv)..."
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
if ! command -v uv >/dev/null 2>&1; then
    fn_info "Installing 'uv' into user space (~/.local/bin)..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    fn_success "'uv' installed successfully!"
else
    fn_success "'uv' is already available."
fi

# 2. Re-install user Python CLI tools from declarative manifest
MANIFEST_FILE="$HOME/.config/tooling/uv-tools.txt"
if [ -f "$MANIFEST_FILE" ]; then
    fn_step "Installing/updating Python tools from uv-tools.txt..."
    while IFS= read -r pkg || [ -n "$pkg" ]; do
        # Ignore comments and blank lines
        [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
        fn_info "Proactively ensuring user tool: $pkg"
        uv tool install --upgrade "$pkg" || fn_error "Warning: Could not install tool $pkg via uv"
    done < "$MANIFEST_FILE"
    fn_success "Declarative Python tool provisioning complete."
else
    fn_info "No manifest found at $MANIFEST_FILE, skipping uv tool installations."
fi

# 3. Ensure Rust User CLI Utilities (Cargo Crates)
if command -v cargo >/dev/null 2>&1; then
    fn_step "Verifying Rust user binary crates..."
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
            fn_info "Installing Rust crate: $crate..."
            cargo install "$crate" || fn_error "Warning: Unable to install $crate via cargo"
        else
            fn_info "Crate executable ready: $cmd"
        fi
    done
    fn_success "Rust crate utilities verified."
else
    fn_info "'cargo' not found in PATH; skipping Rust crate installations."
fi

echo ""
fn_success "Step 01 setup tools complete (No sudo required)!"
echo ""
