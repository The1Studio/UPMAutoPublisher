#!/usr/bin/env bash
# check-single-repo.sh
# Check if a specific repository has UPM workflow set up

set -euo pipefail

# Emojis
CHECK="✅"
CROSS="❌"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <repository-url-or-org/name>"
    echo "Example: $0 The1Studio/UnityBuildScript"
    echo "Example: $0 https://github.com/The1Studio/UnityBuildScript"
    exit 1
fi

INPUT="$1"

# FIX: Parse input with proper validation (use regex instead of sed)
if [[ "$INPUT" =~ ^https?://github\.com/([a-zA-Z0-9_-]+)/([a-zA-Z0-9_-]+)$ ]]; then
    # Full URL provided - extract using BASH_REMATCH
    ORG="${BASH_REMATCH[1]}"
    REPO_NAME="${BASH_REMATCH[2]}"
elif [[ "$INPUT" =~ ^([a-zA-Z0-9_-]+)/([a-zA-Z0-9_-]+)$ ]]; then
    # org/repo format - extract using BASH_REMATCH
    ORG="${BASH_REMATCH[1]}"
    REPO_NAME="${BASH_REMATCH[2]}"
elif [[ "$INPUT" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    # Just repo name - validate alphanumeric only
    REPO_NAME="$INPUT"
    if [ -f "config/repositories.json" ]; then
        # Use jq with proper escaping
        repo_url=$(jq -r --arg name "$REPO_NAME" '.repositories[] | select(.name == $name) | .url' config/repositories.json)
        if [ -n "$repo_url" ] && [ "$repo_url" != "null" ]; then
            # Extract using regex
            if [[ "$repo_url" =~ ^https://github\.com/([a-zA-Z0-9_-]+)/([a-zA-Z0-9_-]+)$ ]]; then
                ORG="${BASH_REMATCH[1]}"
            else
                echo "${CROSS} Invalid URL in config: $repo_url"
                exit 1
            fi
        else
            echo "${CROSS} Repository '$REPO_NAME' not found in config/repositories.json"
            exit 1
        fi
    else
        echo "${CROSS} config/repositories.json not found"
        exit 1
    fi
else
    echo "${CROSS} Invalid input format: $INPUT"
    echo "   Valid formats:"
    echo "   - https://github.com/The1Studio/UnityBuildScript"
    echo "   - The1Studio/UnityBuildScript"
    echo "   - UnityBuildScript"
    exit 1
fi

echo "🔍 Checking: ${ORG}/${REPO_NAME}"
echo "===================="
echo ""

# Check if workflow exists
if gh api "repos/${ORG}/${REPO_NAME}/contents/.github/workflows/publish-upm.yml" >/dev/null 2>&1; then
    echo "${CHECK} Workflow file exists"
    echo ""

    # Get workflow details
    workflow_info=$(gh api "repos/${ORG}/${REPO_NAME}/actions/workflows/publish-upm.yml" 2>/dev/null)

    if [ -n "$workflow_info" ]; then
        echo "Workflow Details:"
        echo "  Name: $(echo "$workflow_info" | jq -r '.name')"
        echo "  State: $(echo "$workflow_info" | jq -r '.state')"
        echo "  Path: $(echo "$workflow_info" | jq -r '.path')"
        echo ""

        # Get run statistics
        runs_info=$(gh api "repos/${ORG}/${REPO_NAME}/actions/workflows/publish-upm.yml/runs?per_page=1" 2>/dev/null)
        total_runs=$(echo "$runs_info" | jq '.total_count')

        echo "Usage:"
        echo "  Total runs: $total_runs"

        if [ "$total_runs" -gt 0 ]; then
            last_run=$(echo "$runs_info" | jq '.workflow_runs[0]')
            last_status=$(echo "$last_run" | jq -r '.conclusion // "running"')
            last_date=$(echo "$last_run" | jq -r '.created_at' | cut -d'T' -f1)

            echo "  Last run: $last_status ($last_date)"
        fi
    fi

    echo ""
    echo "🔗 View in GitHub:"
    echo "  https://github.com/${ORG}/${REPO_NAME}/actions/workflows/publish-upm.yml"

else
    echo "${CROSS} Workflow file does NOT exist"
    echo ""
    echo "To add workflow:"
    echo "  1. Add to config/repositories.json with status: 'pending'"
    echo "  2. Commit and push"
    echo "  3. Automation will create PR"
    echo ""
    echo "📖 See: docs/quick-registration.md"
fi
