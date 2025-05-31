#!/bin/bash

# Default list of folders to ignore
defaultIgnoreFolders=(".venv" "node_modules" "cache" "Cached")

# Determine the correct fd command name
if command -v fd &> /dev/null; then
    FD_CMD="fd"
elif command -v fdfind &> /dev/null; then
    FD_CMD="fdfind"
else
    echo "Error: Neither 'fd' nor 'fdfind' found. Please install fd-find."
    exit 1
fi

# Use yad to select the start path
startPath=$(yad --file-selection --directory --title="Select Start Path")
if [ -z "$startPath" ]; then
    echo "Error: No start path selected."
    exit 1
fi

# Use yad to get additional ignore folders as a comma-separated list
ignoreFoldersInput=$(yad --form --title="Enter Ignore Folders" --field="Ignore Folders (comma-separated):")
if [ -z "$ignoreFoldersInput" ]; then
    echo "No additional folders to ignore, using default."
else
    # Convert the input into an array and append to the default ignore list
    IFS=',' read -r -a additionalIgnoreFolders <<< "$ignoreFoldersInput"
    defaultIgnoreFolders+=("${additionalIgnoreFolders[@]}")
fi

# Construct the fd command dynamically
fd_cmd=($FD_CMD --type d --max-depth 5 -H -I)

# Format ignore pattern correctly using fd's {pattern1,pattern2} syntax
ignorePattern="{"$(IFS=,; echo "${defaultIgnoreFolders[*]}")"}"
fd_cmd+=(-g "$ignorePattern")

# Execute fd and store results
folderList=$("${fd_cmd[@]}" "$startPath" 2>/dev/null)

# Check if fd encountered an error
if [ $? -ne 0 ] || [ -z "$folderList" ]; then
    yad --info --title="Confirmation" --text="No matching folders found or an error occurred. Exiting."
    exit 1
fi

# Show confirmation dialog with found folders
confirmation=$(yad --list --title="Confirm Ignored Folders" --column="Folders to Ignore" <<< "$folderList" --button=Yes:0 --button=No:1)
if [ $? -ne 0 ]; then
    echo "Operation cancelled."
    exit 1
fi

# Process results
echo "$folderList" | while read -r fname; do
    if [ -d "$fname" ]; then
        echo "" > "$fname/.deja-dup-ignore"
        echo "$fname/.deja-dup-ignore created."
    else
        echo "Skipping invalid directory: $fname"
    fi
done
