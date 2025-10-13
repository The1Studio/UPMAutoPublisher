#!/usr/bin/env bash
# check-single-repo.sh
# Check if a specific repository has UPM workflow set up

set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: $0 <repository-url-or-org/name>"
    echo "Example: $0 The1Studio/UnityBuildScript"
    echo "Example: $0 https://github.com/The1Studio/UnityBuildScript"
    exit 1
fi

INPUT="$1"

# Parse input - extract org and repo from URL or org/repo format
if [[ "$INPUT" =~ ^https?:// ]]; then
    # Full URL provided
    ORG=$(echo "$INPUT" | sed -n 's|https\?://github.com/\([^/]*\)/.*|\1|p')
    REPO_NAME=$(echo "$INPUT" | sed -n 's|https\?://github.com/[^/]*/\([^/]*\)|\1|p')
elif [[ "$INPUT" =~ / ]]; then
    # org/repo format
    ORG=$(echo "$INPUT" | cut -d'/' -f1)
    REPO_NAME=$(echo "$INPUT" | cut -d'/' -f2)
else
    # Just repo name - look it up in config
    REPO_NAME="$INPUT"
    if [ -f "config/repositories.json" ]; then
        repo_url=$(jq -r ".repositories[] | select(.name == \"$REPO_NAME\") | .url" config/repositories.json)
        if [ -n "$repo_url" ] && [ "$repo_url" != "null" ]; then
            ORG=$(echo "$repo_url" | sed -n 's|https://github.com/\([^/]*\)/.*|\1|p')
        else
            echo "❌ Repository '$REPO_NAME' not found in config/repositories.json"
            exit 1
        fi
    else
        echo "❌ config/repositories.json not found"
        exit 1
    fi
fi

echo "🔍 Checking: ${ORG}/${REPO_NAME}"
echo "===================="
echo ""

# Check if workflow exists
if gh api "repos/${ORG}/${REPO_NAME}/contents/.github/workflows/publish-upm.yml" >/dev/null 2>&1; then
    echo "✅ Workflow file exists"
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
    echo "❌ Workflow file does NOT exist"
    echo ""
    echo "To add workflow:"
    echo "  1. Add to config/repositories.json with status: 'pending'"
    echo "  2. Commit and push"
    echo "  3. Automation will create PR"
    echo ""
    echo "📖 See: docs/quick-registration.md"
fi
