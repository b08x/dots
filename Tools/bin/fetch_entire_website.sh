#!/bin/bash

# Find the script's own directory
ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)

LIB_DIR="$ROOT_DIR/lib"

source "$LIB_DIR/gum_wrapper.sh"

gum_init

# This script downloads a complete website mirror using wget.
# It takes two arguments:
# 1. The URL of the site to download.
# 2. The local folder to save the site to.

URL="$1"
OUTPUT_FOLDER="$2"

if [ -z "$URL" ] || [ -z "$OUTPUT_FOLDER" ]; then
	echo "Usage: $0 <URL> <OutputFolder>"
	if [ -z "$URL" ]; then
		URL=$(gum_input --placeholder "Enter the URL of the website to download")
		[ -z "$URL" ] && gum_warn "No URL entered, exiting." && exit 1
	fi
	if [ -z "$OUTPUT_FOLDER" ]; then
		OUTPUT_FOLDER=$(gum_file --directory --header "Select Output Directory" "$HOME")
		[ -z "$OUTPUT_FOLDER" ] && gum_warn "No directory selected, exiting." && exit 1
	fi
fi

echo "Starting download for: $URL"
echo "Saving to: $OUTPUT_FOLDER"

log "Starting download for: ${URL}"
# Create the output directory if it doesn't exist.
# -p flag ensures no error if the directory already exists
# and creates parent directories as needed.
mkdir -p "$OUTPUT_FOLDER"

# Execute the wget command with the provided URL and output directory.
# --recursive: Follow links to download recursively.
# --level=inf: Set recursion depth to infinity (download everything).
# --convert-links: Convert links in downloaded files to point to local files.
# --page-requisites: Download all necessary files (CSS, images, etc.) for each page.
# --no-parent: Don't ascend to the parent directory (keeps download focused).
# -P "$OUTPUT_FOLDER": Specifies the directory prefix (where to save files).
# "$URL": The URL to start downloading from. Quoted to handle special characters.
wget --recursive --level=inf --convert-links --page-requisites --no-parent -P "$OUTPUT_FOLDER" "$URL"

echo "Download complete."
