---
name: bluefin-builder
description: A comprehensive skill for building custom Bluefin images. This skill guides users through customizing and building their own Bluefin-based operating system images using the syncopated-os template.
user-invocable: true
allowed-tools: bash read_file write_file search_replace grep
---

# Bluefin Builder Skill

## Overview
This skill provides comprehensive guidance for building custom Bluefin images using the syncopated-os template. It covers the entire process from repository setup to advanced optimizations.

## Key Components

### 1. Build System
- Automated builds via GitHub Actions on every commit
- Self-hosted Renovate setup for keeping images and actions up to date
- Automatic cleanup of old images (90+ days)
- Pull request workflow for testing changes before merging to main
- Validates files on pull requests (Brewfile, Justfile, ShellCheck, Renovate config, Flatpak existence)

### 2. Homebrew Integration
- Pre-configured Brewfiles for easy package installation and customization
- Curated collections: development tools, fonts, CLI utilities
- Users install packages at runtime with `brew bundle`
- Aliased to premade `ujust` commands

### 3. Flatpak Support
- Ship favorite flatpaks
- Automatically installed on first boot after user setup
- Customization guide available

### 4. ujust Commands
- User-friendly command shortcuts via `ujust`
- Pre-configured examples for app installation and system maintenance
- Customization guide available

### 5. Build Scripts
- Modular numbered scripts (10-, 20-, 30-) run in order
- Example scripts included for third-party repositories and desktop replacement
- Helper functions for safe COPR usage

### 6. Security Features
- **Image Signing**: Optional image signing with cosign for cryptographic verification
- **SBOM Attestation**: Software Bill of Materials generation for supply chain transparency
- Automated security updates via Renovate
- Build provenance tracking

### 7. Advanced Features
- **Image Rechunking**: Optimizes bootc image layers for better update performance
- Reduces update sizes by 5-10x
- Improves download resumability with evenly sized layers

## Quick Start Guide

### 1. Create Your Repository
Click "Use this template" to create a new repository from the syncopated-os template.

### 2. Rename the Project
Change `syncopated-os` to your repository name in these 6 files:
1. `Containerfile` (line 4): `# Name: your-repo-name`
2. `Justfile` (line 1): `export image_name := env("IMAGE_NAME", "your-repo-name")`
3. `README.md` (line 1): `# your-repo-name`
4. `artifacthub-repo.yml` (line 5): `repositoryID: your-repo-name`
5. `custom/ujust/README.md` (~line 175): `localhost/your-repo-name:stable`
6. `.github/workflows/clean.yml` (line 23): `packages: your-repo-name`

### 3. Enable GitHub Actions
- Go to the "Actions" tab in your repository
- Click "I understand my workflows, go ahead and enable them"

### 4. Customize Your Image
Choose your base image in `Containerfile` (line 23):
```dockerfile
FROM ghcr.io/ublue-os/bluefin:stable
```

Add your packages in `build/10-build.sh`:
```bash
dnf5 install -y package-name
```

Customize your apps:
- Add Brewfiles in `custom/brew/`
- Add Flatpaks in `custom/flatpaks/`
- Add ujust commands in `custom/ujust/`

### 5. Development Workflow
All changes should be made via pull requests:
1. Open a pull request on GitHub with the change you want
2. The PR will automatically trigger:
   - Build validation
   - Brewfile, Flatpak, Justfile, and shellcheck validation
   - Test image build
3. Once checks pass, merge the PR
4. Merging triggers publishes a `:stable` image

### 6. Deploy Your Image
Switch to your image:
```bash
sudo bootc switch ghcr.io/your-username/your-repo-name:stable
sudo systemctl reboot
```

## Security Features

### Enable Image Signing
1. Generate signing keys:
```bash
cosign generate-key-pair
```

2. Add the private key to GitHub Secrets:
   - Copy the entire contents of `cosign.key`
   - Go to your repository on GitHub
   - Navigate to Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `SIGNING_SECRET`
   - Value: Paste the entire contents of `cosign.key`
   - Click "Add secret"

3. Replace the contents of `cosign.pub` with your public key

4. Enable signing in the workflow:
   - Edit `.github/workflows/build.yml`
   - Find the "OPTIONAL: Image Signing with Cosign" section
   - Uncomment the steps to install Cosign and sign the image
   - Commit and push the change

### Enable SBOM Attestation
1. First complete image signing setup
2. Edit `.github/workflows/build.yml`
3. Find the "OPTIONAL: SBOM Attestation" section around line 232
4. Uncomment the "Add SBOM Attestation" step
5. Commit and push

### Enable Image Rechunking
Add a rechunk step after the build in `.github/workflows/build.yml`:

```yaml
- name: Rechunk Image
  run: |
    sudo podman run --rm --privileged \
      -v /var/lib/containers:/var/lib/containers \
      --entrypoint /usr/libexec/bootc-base-imagectl \
      "localhost/${IMAGE_NAME}:${DEFAULT_TAG}" \
      rechunk --max-layers 67 \
      "localhost/${IMAGE_NAME}:${DEFAULT_TAG}" \
      "localhost/${IMAGE_NAME}:${DEFAULT_TAG}-rechunked"
    
    # Tag the rechunked image with the original tag
    sudo podman tag "localhost/${IMAGE_NAME}:${DEFAULT_TAG}-rechunked" "localhost/${IMAGE_NAME}:${DEFAULT_TAG}"
    sudo podman rmi "localhost/${IMAGE_NAME}:${DEFAULT_TAG}-rechunked"
```

## Detailed Guides

### Homebrew/Brewfiles
- Runtime package management
- Pre-configured Brewfiles for easy customization
- Users install packages at runtime with `brew bundle`
- See `custom/brew/README.md` for details

### Flatpak Preinstall
- GUI application setup
- Ship your favorite flatpaks
- Automatically installed on first boot after user setup
- See `custom/flatpaks/README.md` for details

### ujust Commands
- User convenience commands
- Pre-configured examples for app installation and system maintenance
- See `custom/ujust/README.md` for details

### Build Scripts
- Build-time customization
- Modular numbered scripts (10-, 20-, 30-) run in order
- Example scripts included for third-party repositories and desktop replacement
- Helper functions for safe COPR usage
- See `build/README.md` for details

## Architecture

This template follows the **multi-stage build architecture** from @projectbluefin/distroless:

### Multi-Stage Build Pattern

**Stage 1: Context (ctx)** - Combines resources from multiple sources:
- Local build scripts (`/build`)
- Local custom files (`/custom`)
- **@projectbluefin/common** - Desktop configuration shared with Aurora
- **@projectbluefin/branding** - Branding assets
- **@ublue-os/artwork** - Artwork shared with Aurora and Bazzite
- **@ublue-os/brew** - Homebrew integration

**Stage 2: Base Image** - Default options:
- `ghcr.io/ublue-os/silverblue-main:latest` (Fedora-based, default)
- `quay.io/centos-bootc/centos-bootc:stream10` (CentOS-based alternative)

### Benefits of This Architecture
- **Modularity**: Compose your image from reusable OCI containers
- **Maintainability**: Update shared components independently
- **Reproducibility**: Renovate automatically updates OCI tags to SHA digests
- **Consistency**: Share components across Bluefin, Aurora, and custom images

## Local Testing

Test your changes before pushing:
```bash
just build              # Build container image
just build-qcow2        # Build VM disk image
just run-vm-qcow2       # Test in browser-based VM
```

## Build Command Execution via Subagent

The bluefin-builder agent can delegate build command execution to a specialized subagent for better isolation and reporting.

### When to Use the Subagent
- Running potentially long build commands (`just build`, `just build-qcow2`)
- Executing commands that need precise output capture
- When you want detailed execution reports for diagnosis

### How to Use the Subagent
The main agent can spawn the subagent using the `task` tool:

```json
{
  "task": "Run build command and report results",
  "agent": "bluefin-builder-subagent"
}
```

### Subagent Capabilities
- Executes build commands with precise timing and output capture
- Returns structured reports with exit codes, stdout, stderr, and duration
- Auto-approves operations for efficient execution
- Limited tool access (bash, read_file only) for security

### Example Workflow
1. Main agent identifies need to run a build command
2. Main agent spawns subagent with specific build command
3. Subagent executes command and captures all output
4. Subagent returns structured report to main agent
5. Main agent analyzes results and makes decisions

## Community Resources
- [Universal Blue Discord](https://discord.gg/WEu6BdFEtp)
- [bootc Discussion](https://github.com/bootc-dev/bootc/discussions)

## Learn More
- [Universal Blue Documentation](https://universal-blue.org/)
- [bootc Documentation](https://containers.github.io/bootc/)
- [Video Tutorial by TesterTech](https://www.youtube.com/watch?v=IxBl11Zmq5wE)

## Best Practices
1. Always use pull requests for changes
2. Test changes locally before pushing
3. Enable security features for production use
4. Keep your base image updated
5. Document your customizations
6. Engage with the community for support and ideas