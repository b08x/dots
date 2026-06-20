#!/usr/bin/env bash
# =============================================================================
# YADM Bootstrap Step: Install Prerequisites (Ansible & System Core)
# =============================================================================

echo "============================================================================="
echo "Bootstrapping prerequisites for Workstation Setup..."
echo "============================================================================="

# 1. Update/Install Ansible and dependencies via DNF
if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "Installing Ansible and dependencies..."
    sudo dnf install -y ansible git python3-pip python3-devel
else
    echo "Ansible is already installed."
fi

# 2. Install community collections if needed
echo "Verifying Ansible collections..."
ansible-galaxy collection install community.general ansible.posix --upgrade

echo "Prerequisites bootstrap complete! Ready to run Ansible."
