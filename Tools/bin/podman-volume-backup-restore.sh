#!/bin/bash

# ------------------------------------------------------------------------------
# Script Name: podman-volume-backup-restore.sh
# Description: This script provides an interactive way to back up and restore
#              Podman volumes using native export/import commands and the 'gum'
#              tool for enhanced UI.
#
# Requirements:
#   - gum: Install from https://github.com/charmbracelet/gum
#   - fd:  Install from https://github.com/sharkdp/fd
#   - sd:  Install from https://github.com/chmln/sd
#   - podman: Podman must be installed and running
#
# Usage:
#   - Interactive mode:
#       ./podman-volume-backup-restore.sh
#
#   - Backup all volumes to default directory:
#       ./podman-volume-backup-restore.sh backup
#
#   - Backup specific volumes to default directory:
#       ./podman-volume-backup-restore.sh backup volume1 volume2 ...
#
#   - Backup with custom directory:
#       ./podman-volume-backup-restore.sh --backup-dir=/custom/path backup
#
#   - Restore volumes (interactive selection from backups):
#       ./podman-volume-backup-restore.sh restore
#
#   - Restore from custom directory:
#       ./podman-volume-backup-restore.sh --backup-dir=/custom/path restore
# ------------------------------------------------------------------------------

# --- Configuration ------------------------------------------------------------

# Default backup directory
backup_dir="$HOME/LLMOS/BACKUP/podman-volumes"

# Parse --backup-dir flag before processing actions
while [[ $# -gt 0 ]]; do
  case "$1" in
    --backup-dir=*)
      backup_dir="${1#*=}"
      shift
      ;;
    --backup-dir)
      backup_dir="$2"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

# --- Functions ---------------------------------------------------------------

# Function to handle script exit
function handle_exit {
  echo -e "\n\nExiting script..."
  exit 0
}

# Function to detect Podman mode
function detect_podman_mode {
  if podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null | grep -q "true"; then
    echo "ℹ️  Running in rootless Podman mode"
  else
    echo "ℹ️  Running in rootful Podman mode"
  fi
}

# Function to backup Podman volumes
# Arguments: (optional) List of volumes to back up. If none are provided,
#            interactive selection will be presented.
function backup_volumes {
  local volumes_to_backup
  local backup_file
  local timestamp

  # Detect and display Podman mode
  detect_podman_mode

  # Get a list of all Podman volumes
  all_volumes=($(podman volume ls -q))

  if [[ ${#all_volumes[@]} -eq 0 ]]; then
    echo "No Podman volumes found."
    exit 0
  fi

  # Use gum choose for interactive volume selection (if no arguments)
  if [[ $# -eq 0 ]]; then
    volumes_to_backup=$(gum choose "${all_volumes[@]}" --no-limit --header "Select volumes to backup")
    if [[ -z "$volumes_to_backup" ]]; then
      echo "No volumes selected for backup."
      exit 0
    fi
  else
    volumes_to_backup=("$@")
  fi

  # Create backup directory if it doesn't exist
  mkdir -p "$backup_dir"

  echo "📦 Backup directory: $backup_dir"
  echo ""

  # Backup each selected volume
  for volume in $volumes_to_backup; do
    timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    backup_file="$backup_dir/${volume}_backup_${timestamp}.tar"

    echo "💾 Backing up volume: $volume"
    echo "   → $backup_file"

    if podman volume export "$volume" -o "$backup_file"; then
      echo "   ✅ Backup completed successfully"
    else
      echo "   ❌ Backup failed"
    fi
    echo ""
  done

  echo "🎉 Backup operation complete!"
  echo "📁 Backups stored in: $backup_dir"
}

# Function to restore Podman volumes
function restore_volumes {
  local backup_file
  local selected_backup
  local volume_name
  local available_backups

  # Detect and display Podman mode
  detect_podman_mode

  # Check if backup directory exists
  if [[ ! -d "$backup_dir" ]]; then
    echo "❌ Error: Backup directory not found: $backup_dir"
    exit 1
  fi

  # Find all .tar backup files in the backup directory
  available_backups=$(fd -t f -e tar . "$backup_dir" --exec basename {} .tar 2>/dev/null)

  if [[ -z "$available_backups" ]]; then
    echo "No backup files found in: $backup_dir"
    exit 1
  fi

  echo "📂 Backup directory: $backup_dir"
  echo ""

  # Use gum filter for interactive backup selection
  selected_backup=$(echo "$available_backups" | gum filter --placeholder "Search and select backup to restore" --header "Available backups:")

  if [[ -z "$selected_backup" ]]; then
    echo "No backup selected for restoration."
    exit 0
  fi

  # Extract volume name from backup filename (remove _backup_DATE suffix)
  volume_name=$(echo "$selected_backup" | sd '_backup_.*' '')
  backup_file="$backup_dir/${selected_backup}.tar"

  echo "📦 Restoring volume: $volume_name"
  echo "   From: $backup_file"
  echo ""

  # Ask for confirmation
  if gum confirm "Restore volume '$volume_name'? This will overwrite existing data."; then
    # Create volume if it doesn't exist (ignore error if it already exists)
    podman volume create "$volume_name" 2>/dev/null || true

    # Import backup into volume
    if podman volume import "$volume_name" "$backup_file"; then
      echo "✅ Volume restored successfully!"
    else
      echo "❌ Error: Failed to restore volume"
      exit 1
    fi
  else
    echo "Restore cancelled."
    exit 0
  fi
}

# --- Main Script Execution ----------------------------------------------------

# Handle script termination using trap for SIGINT (Ctrl+C) and SIGTSTP (Ctrl+Z)
trap handle_exit SIGINT SIGTSTP

# Clear the screen
tput clear && tput cup 15 0

# Check for command line arguments
if [[ $# -eq 0 ]]; then
  # Interactive mode - show menu
  choice=$(gum choose --cursor-prefix "▸ " --selected-prefix "✓ " "Backup volumes" "Restore volumes")

  case "$choice" in
    "Backup volumes")
      backup_volumes
      ;;
    "Restore volumes")
      restore_volumes
      ;;
    *)
      echo "Invalid choice. Exiting."
      exit 1
      ;;
  esac
else
  # Non-interactive mode - use command line arguments
  action="$1"
  shift # Remove action from arguments

  case "$action" in
    backup)
      backup_volumes "$@"
      ;;
    restore)
      restore_volumes
      ;;
    *)
      echo "❌ Invalid action: $action"
      echo ""
      echo "Usage:"
      echo "  $0 [--backup-dir=PATH] backup [volume1 volume2 ...]"
      echo "  $0 [--backup-dir=PATH] restore"
      echo ""
      exit 1
      ;;
  esac
fi
