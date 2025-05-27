#!/bin/bash

# Script to extract markdown content from a URL and copy it to the clipboard.

# Check if a URL is provided as an argument.
if [ -z "$1" ]; then
  echo "Usage: $0 <URL>"
  exit 1
fi

# Get the URL from the first argument.
URL="$1"

# Extract markdown content from the URL using trafilatura and copy it to the clipboard using xclip.
trafilatura --output-format markdown -u "$URL" | xclip -selection clipboard

# Optional: Print a success message.
echo "Markdown content from '$URL' copied to clipboard."

exit 0
