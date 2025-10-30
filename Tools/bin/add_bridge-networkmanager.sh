#!/usr/bin/env zsh

# Ensure the script exits if a command fails
set -e

# --- Configuration Functions ---

# Check for required dependencies
check_dependencies() {
  local missing_deps=0
  for cmd in gum nmcli ifconfig awk sed; do
    if ! command -v "$cmd" &> /dev/null; then
      echo "Error: Required command '$cmd' is not installed." >&2
      missing_deps=1
    fi
  done

  if (( missing_deps )); then
    echo "Please install the missing dependencies and try again." >&2
    exit 1
  fi
}

# Gather network configuration from the user
get_network_config() {
  echo "Enter bridge interface name:"
  bridge_name=$(gum input --placeholder="br0" --value="br0")

  echo "Choose an interface to use as a bridge slave:"
  # Use zsh's array capabilities for a cleaner pipeline
  local interfaces=("${(@f)$(ifconfig | awk '/^[a-z]/ && !/lo/{print $1}' | sed 's/://')}")
  bridge_slave=$(gum choose "${interfaces[@]}")

  echo "Enter IP address for the bridge interface:"
  # Suggest the current IP of the selected slave interface
  local current_ip
  current_ip=$(ip address show dev "$bridge_slave" | awk '/inet / {print $2}')
  ipaddr=$(gum input --placeholder="${current_ip:-192.168.1.100/24}" --value="${current_ip}")

  echo "Enter gateway:"
  # Suggest a gateway based on the IP
  local suggested_gateway="${ipaddr%.*.*/*}.1"
  gateway=$(gum input --placeholder="${suggested_gateway}" --value="${suggested_gateway}")

  echo "Enter DNS server:"
  dns=$(gum input --placeholder="${gateway}" --value="${gateway}")

  echo "Enter DNS search domain:"
  search=$(gum input --placeholder="syncopated.net" --value="syncopated.net")
}

# Display the configuration and ask for confirmation
confirm_config() {
  clear
  gum style \
    --border normal --margin "1" --padding "1 2" --border-foreground 212 \
    "Bridge Configuration Review" \
    "\n    Bridge Name:      $(gum style --foreground 212 "$bridge_name")\n    Bridge Slave:     $(gum style --foreground 212 "$bridge_slave")\n    IP Address:       $(gum style --foreground 212 "$ipaddr")\n    Gateway:          $(gum style --foreground 212 "$gateway")\n    DNS Server:       $(gum style --foreground 212 "$dns")\n    DNS Search:       $(gum style --foreground 212 "$search")\n    "

  gum confirm "Does this all look correct?"
}

# Apply the network configuration using nmcli
apply_network_config() {
  echo "Applying network configuration..."

  # Add the new bridge connection
  sudo nmcli connection add type bridge autoconnect yes con-name "$bridge_name" ifname "$bridge_name"

  # Configure the bridge's IP settings
  sudo nmcli connection modify "$bridge_name" ipv4.addresses "$ipaddr" ipv4.method manual
  sudo nmcli connection modify "$bridge_name" ipv4.gateway "$gateway"
  sudo nmcli connection modify "$bridge_name" ipv4.dns "$dns"
  sudo nmcli connection modify "$bridge_name" ipv4.dns-search "$search"

  # Find and delete the old connection for the slave interface
  local old_connection
  old_connection=$(nmcli -g NAME,DEVICE connection show | awk -F: -v dev="$bridge_slave" '$2 == dev {print $1}')
  if [[ -n "$old_connection" ]]; then
    echo "Deleting old connection '$old_connection' for interface '$bridge_slave'."
    sudo nmcli connection delete "$old_connection"
  else
    echo "No existing connection found for '$bridge_slave'. Proceeding..."
  fi

  # Add the slave interface to the bridge
  sudo nmcli connection add type bridge-slave autoconnect yes con-name "$bridge_slave" ifname "$bridge_slave" master "$bridge_name"

  echo "Network bridge '$bridge_name' created successfully."
}

# --- Main Script Logic ---

main() {
  check_dependencies
  get_network_config

  if confirm_config; then
    apply_network_config
    echo
    if gum confirm "Configuration applied. Reboot now to activate?"; then
      sudo shutdown -r now
    else
      echo "Please reboot manually to apply changes."
    fi
  else
    echo "Operation cancelled by user. Exiting."
    exit 1
  fi
}

# Run the main function
main