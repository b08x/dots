# $HOME/Workspace/Tools

Scripts that either perform a task (install something) or return output

scripts in lib can be executed manually


## [setup_python_spacy.sh](./lib/setup_python_spacy.sh)

Script to optionally install a specific Python version from source, then uv,
and finally create a virtual environment with spaCy (and a transformer model)
installed via uv and spaCy CLI, with a Gum-enhanced UI.


## [gum_wrapper.sh](./lib/gum_wrapper.sh)

This script provides a comprehensive set of Bash helper functions and a wrapper around the `gum` tool ([charmbracelet/gum](https://github.com/charmbracelet/gum)). It aims to simplify the creation of interactive and visually appealing command-line interfaces within your shell scripts. It includes automatic `gum` installation, standardized output styling, robust error handling, and wrappers for common `gum` commands.

### Features

* **Automatic `gum` Installation:** Detects if `gum` is installed. If not, it downloads and installs a specific version (`0.13.0` by default) to `$HOME/.local/bin/`.
* **Standardized Output:** Provides functions like `gum_info`, `gum_warn`, `gum_fail`, and `gum_title` for consistent, colored messaging.
* **`gum` Command Wrappers:** Simplifies calls to `gum` for common UI elements like confirmations, inputs, choices, filters, and spinners, applying consistent styling.
* **Robust Error Handling:** Implements `trap` functions to catch errors (`ERR`) and script exits (`EXIT`). It logs errors, displays user-friendly messages, and offers to show logs upon failure.
* **Temporary File Management:** Automatically creates and cleans up temporary directories used during execution.

### Dependencies

* `bash`
* `curl` (for downloading `gum` if needed)
* `tar` (for extracting `gum` if needed)
* Standard Unix utilities (`mktemp`, `find`, `mkdir`, `mv`, `chmod`, `uname`).

### Usage

To use these helpers in your own Bash scripts, you need to `source` the `gum_wrapper.sh` file. It's crucial to define the `SCRIPT_LOG` variable *before* sourcing the script, as the error handling relies on it.

```bash
#!/usr/bin/env bash

# Define the project's root directory (adjust as necessary)
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define the log file path (IMPORTANT: Define *before* sourcing)
export SCRIPT_LOG="/tmp/my_script.log"

# Source the gum wrapper
source "${TOOLS_DIR}/lib/gum_wrapper.sh"

# --- Your script logic starts here ---

# Optional: Initialize gum explicitly if needed (though it often runs on first use)
# gum_init || exit 1 # Exit if gum can't be set up

# Example usage:
log "INFO" "Starting the main script logic."

gum_title "Welcome to My Awesome Script!"
gum_info "This script will guide you through the setup."

# Get user input
user_name=$(gum_input --header "What is your name?" --value "Developer")
if [ -z "$user_name" ]; then
    gum_fail "Name cannot be empty. Exiting."
    exit 1
fi
gum_info "Hello, ${user_name}!"

# Get confirmation
if gum_confirm "Do you want to proceed with the risky operation?"; then
    gum_warn "Proceeding with the risky operation..."
    # Simulate a command that might fail
    (ls /non_existent_directory && gum_info "Operation successful (this won't print).") || {
        # The trap will catch this failure
        log "ERROR" "Simulated operation failed as expected."
        # The script will exit via the trap_exit function.
        # No need for 'exit 1' here usually, but added for clarity
        # in this example if traps weren't perfectly set.
        exit 1
    }
else
    gum_info "Operation cancelled."
fi

# This part will likely not be reached if the risky operation fails
gum_info "Script finished (if operation succeeded)."

# The exit trap will handle the final success message.
```

### Key Functions

#### Output Formatting

* `gum_white <text>`: Prints text in white.
* `gum_purple <text>`: Prints text in purple.
* `gum_yellow <text>`: Prints text in yellow.
* `gum_red <text>`: Prints text in red.
* `gum_green <text>`: Prints text in green.
* `gum_title <text>`: Displays a styled title.
* `gum_info <text>`: Displays an informational message.
* `gum_warn <text>`: Displays a warning message.
* `gum_fail <text>`: Displays an error/failure message.

#### `gum` Wrappers

* `gum_style <args>`: Direct wrapper for `gum style`.
* `gum_confirm <text>`: Prompts for a yes/no confirmation.
* `gum_input <args>`: Prompts for single-line text input.
* `gum_write <args>`: Prompts for multi-line text input.
* `gum_choose <options>`: Presents a list for single-choice selection.
* `gum_filter <options>`: Presents a filterable list for selection.
* `gum_spin <command>`: Displays a spinner while a command runs.

#### Key/Value Display

* `gum_proc <key> <value>`: Displays a key-value pair, often used for processes or steps.
* `gum_property <key> <value>`: Displays a key-value pair, often used for configuration or properties.

### Error Handling & Logging

The script sets up `ERR` and `EXIT` traps.

* **`trap_error`:** When a command fails, it logs the command, function name, and line number to `$SCRIPT_TMP_DIR/gum_helpers.err` and to `$SCRIPT_LOG`.
* **`trap_exit`:** When the script exits (normally, due to error, or `Ctrl+C`):
    * It cleans up the temporary directory.
    * If `Ctrl+C` was pressed, it prints a simple exit message.
    * If an error occurred, it reads the error message (if available), prints it using `gum_fail`, and offers to show the `$SCRIPT_LOG` file using `gum pager`.
    * If the script completed successfully, it prints a success message.
    * It always exits with the correct exit code.

**Important:** You *must* define the `SCRIPT_LOG` environment variable in your main script *before* sourcing `gum_wrapper.sh` for the "Show Logs?" feature to work correctly.

### Customization

* **`GUM_VERSION`:** You can change the `gum` version to download by setting this variable *before* sourcing the script.
* **`GUM` Path:** You can force the script to use a specific `gum` executable by setting the `GUM` environment variable (e.g., `GUM=/usr/local/bin/gum ./your_script.sh`).
* **Colors:** The color variables (`COLOR_WHITE`, `COLOR_GREEN`, etc.) can be modified within `gum_wrapper.sh` to change the theme. Refer to the `termenv` color chart for values.