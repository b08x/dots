Backlog to GitHub IssuesI will locate your most recent backlog-*.json file, parse the tasks within it, and create professional GitHub issues. This process should, in theory, translate your structured planning into actionable items.First, I'll analyze your project's context to ensure the issues I create don't immediately violate some unwritten rule.Documentation Analysis:Read README.md for project overview.Read CONTRIBUTING.md for contribution guidelines.Read .github/ISSUE_TEMPLATE/* for issue formats.Read docs/ folder for any other hidden instructions.Project Context:Repository type (fork, personal, organization)Main language and framework conventionsTesting requirements and CI/CD setupThen, I'll verify the necessary tools are in place. It would be a shame to fail on a technicality.# Check if we're in a git repository with a GitHub remote
if ! git remote -v | grep -q github.com; then
    echo "Error: This does not appear to be a GitHub repository."
    exit 1
fi

# Check for the GitHub CLI (gh)
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) not found. Please install it."
    exit 1
fi

# Verify authentication status
if ! gh auth status &>/dev/null; then
    echo "Error: You are not authenticated with GitHub. Please run 'gh auth login'."
    exit 1
fi
Locating and Processing the Backlog FileI will find the most recently modified backlog file and process its contents using the function below.# Find the latest backlog file based on modification time
LATEST_BACKLOG_FILE=$(ls -t backlog-*.json 2>/dev/null | head -n 1)

if [ -z "$LATEST_BACKLOG_FILE" ]; then
    echo "Error: No 'backlog-*.json' file found."
    exit 1
fi

echo "Processing file: $LATEST_BACKLOG_FILE"

# Function to process each task from the backlog file
process_backlog() {
    local file="$1"
    
    # Check if jq is installed, as it's essential for parsing the JSON backlog
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed. Please install it to parse JSON."
        exit 1
    fi

    # Use jq to read the file and pipe each task object into the while loop
    jq -c '.productBacklog[]' "$file" | while IFS= read -r task; do
        # Extract details from the JSON object for each task
        local issueId=$(echo "$task" | jq -r '.issueId')
        local userStory=$(echo "$task" | jq -r '.userStory')
        local taskDescription=$(echo "$task" | jq -r '.taskDescription')
        local epic=$(echo "$task" | jq -r '.epic')
        
        # Extract and format acceptance criteria into a markdown checklist
        local acceptanceCriteriaMd=$(echo "$task" | jq -r '.llmAssistantPrompt.acceptanceCriteria[]' | sed 's/^/- [ ] /')
        
        # Derive the issue type label from the issueId prefix (e.g., "BUG-001" -> "bug")
        local typeLabel=$(echo "$issueId" | cut -d'-' -f1 | tr '[:upper:]' '[:lower:]')

        # Construct the issue title for clarity and traceability
        local title="[$issueId] $userStory"
        
        # Construct the issue body using the extracted information
        local body=$(cat <<EOF
### User Story
> $userStory

### Task Description
$taskDescription

### Acceptance Criteria
$acceptanceCriteriaMd
EOF
)
        
        echo "Creating issue for: $issueId"
        # Create the GitHub issue with a title, body, and appropriate labels
        gh issue create --title "$title" --body "$body" --label "$typeLabel" --label "$epic"
        
        # A brief, polite pause to avoid overwhelming the GitHub API
        sleep 1
    done
    
    echo "Backlog processing complete."
}

# Call the function with the located backlog file to begin creating issues
process_backlog "$LATEST_BACKLOG_FILE"
ImportantI will not add any "Created by AI" attributions or other watermarks to the issues. The goal is to create native, human-quality issues that seamlessly integrate into your existing workflow.
