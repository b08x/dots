#!/usr/bin/env bash
# =============================================================================
# YADM Bootstrap Step 03: Security Hardening & Permission Sanitization (Layer 2)
# =============================================================================
set -e

if [ -f "$HOME/.config/yadm/scripts/gum-helpers.sh" ]; then
    source "$HOME/.config/yadm/scripts/gum-helpers.sh"
    gum_init || true
else
    function fn_header() { echo "=== $1 ==="; }
    function fn_step() { echo "➜ $1"; }
    function fn_info() { echo "  i $1"; }
    function fn_success() { echo "✓ $1"; }
fi

fn_header "Security & Permission Hardening"

# 1. Secure SSH and GPG vaults
fn_step "Auditing SSH and GPG directory permissions..."
for vault in "$HOME/.ssh" "$HOME/.gnupg"; do
    if [ -d "$vault" ]; then
        chmod 700 "$vault" || true
        find "$vault" -type f -exec chmod 600 {} + 2>/dev/null || true
        fn_info "Secured permissions (700 dir / 600 files): $vault"
    fi
done

# 2. Lock down AI agent tokens and global environment files
fn_step "Locking down AI agent profiles and configuration credentials..."
for secret_file in "$HOME/.claude.json" "$HOME/.codex/auth.json" "$HOME/.git-credentials"; do
    if [ -f "$secret_file" ]; then
        chmod 600 "$secret_file" || true
        fn_info "Sanitized permission (mode 600): $secret_file"
    fi
done

# 3. Secure Hermes profile auth and environment files
if [ -d "$HOME/.hermes/profiles" ]; then
    fn_step "Securing Hermes profile tokens and .env files..."
    find "$HOME/.hermes/profiles/" \( -name "auth.json" -o -name ".env" \) -exec chmod 600 {} + 2>/dev/null || true
    fn_info "Applied mode 600 to all discovered Hermes credentials."
fi

# 4. Ensure SSH config has valid file mode if it exists
if [ -f "$HOME/.ssh/config" ]; then
    chmod 600 "$HOME/.ssh/config" || true
fi

echo ""
fn_success "Step 03 security permission hardening complete!"
echo ""
