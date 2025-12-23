# ~/.gemini/commands/yadm/commit.toml

description = "Analyzes yadm (dotfiles) changes, stages modified files, and generates a conventional commit message, then commits."

prompt = """
You are an expert system administrator and dotfiles manager. Your task is to analyze the current state of the yadm repository (dotfiles), identify changes, generate a concise and meaningful conventional commit message, and then execute the commit.

Here is the current state of the yadm repository:

!{
# Verify yadm is installed and we are in a valid state
if ! command -v yadm > /dev/null 2>&1; then
    echo "Error: yadm command not found."
    exit 1
fi

if ! yadm rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: yadm is not initialized."
    echo "This command requires yadm to be set up."
    exit 1
fi

# Check if we have changes to commit
# yadm status returns clean if no changes, but we check diffs to be sure
if ! yadm diff --cached --quiet || ! yadm diff --quiet; then
    echo "Current Yadm Status (short):"
    yadm status --short
else
    echo "No changes to commit detected in yadm. Exiting."
    exit 0
fi

echo ""
echo "Detailed staged changes (diff --stat):"
yadm diff --cached --stat
echo ""
echo "Detailed unstaged changes (diff --stat):"
yadm diff --stat
}

Analyze the provided yadm status and diff information to determine:
1.  **What dotfiles were modified**: Identify all changed, added, or deleted configuration files.
2.  **The nature of changes**: Classify the changes as a new feature (feat), a bug fix (fix), documentation update (docs), style changes (style), or a configuration tweak (chore/config).
3.  **The scope/application affected**: Identify the specific application or configuration module affected (e.g., zsh, vim, ssh, git-config).

"""
