#!/bin/bash

# Script to extract markdown content from a list of URLs and save each
# to a separate markdown file in a user-selected directory.

# Check if gum is installed.
if ! command -v gum &> /dev/null; then
    echo "Error: gum is not installed. Please install it to continue."
    exit 1
fi

# Check if trafilatura is installed.
if ! command -v trafilatura &> /dev/null; then
    echo "Error: trafilatura is not installed. Please install it to continue."
    exit 1
fi

# Get the list of URLs from the user using gum's text input area.
URLS=$(gum write --placeholder "Enter each URL on a new line...")

# Exit if no URLs were provided.
if [ -z "$URLS" ]; then
  echo "No URLs provided. Exiting."
  exit 0
fi

# Ask the user to select an output directory using gum's file picker.
# The user should navigate to the desired directory and press Enter.
OUTPUT_DIR=$(gum file --directory)

# Exit if no directory was selected.
if [ -z "$OUTPUT_DIR" ]; then
  echo "No output directory selected. Exiting."
  exit 1
fi

# Ensure the selected path is a directory.
if [ ! -d "$OUTPUT_DIR" ]; then
  echo "Error: The selected path '$OUTPUT_DIR' is not a directory."
  exit 1
fi

# Process each URL from the input.
echo "$URLS" | while IFS= read -r URL; do
  # Ignore empty or invalid lines.
  if [[ -z "$URL" || ! "$URL" =~ ^https?:// ]]; then
    continue
  fi

  echo "Processing URL: $URL"

  # Extract markdown content from the URL.
  if ! MARKDOWN_CONTENT=$(trafilatura --output-format markdown -u "$URL"); then
    echo "  Warning: Failed to extract content from '$URL'."
    continue
  fi

  # Skip if no content was extracted.
  if [ -z "$MARKDOWN_CONTENT" ]; then
    echo "  Warning: No content extracted from '$URL'."
    continue
  fi

  # Generate a filename from the page title.
  FILENAME=$(echo "$MARKDOWN_CONTENT" | head -n 1 | sed -e 's/^[# ]*//' -e 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]').md

  # Create a fallback filename if the title is empty.
  if [ "$FILENAME" == ".md" ]; then
    FILENAME="url-output-$(date +%s%N).md"
  fi

  # Define the full path for the output file.
  OUTPUT_FILE="$OUTPUT_DIR/$FILENAME"

  # Save the content to the markdown file.
  echo "$MARKDOWN_CONTENT" > "$OUTPUT_FILE"

  echo "  Content saved to '$OUTPUT_FILE'"

done

echo "All URLs processed successfully."

exit 0
