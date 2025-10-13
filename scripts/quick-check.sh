#!/usr/bin/env bash
# quick-check.sh
# Quick status check for all registered repositories

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Emojis
CHECK="✅"
CROSS="❌"

echo "🔍 Quick Status Check"
echo "===================="
echo ""

# Check prerequisites quietly
if [ ! -f "config/repositories.json" ]; then
    echo "${CROSS} Error: config/repositories.json not found"
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo "${CROSS} Error: GitHub CLI not installed"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "${CROSS} Error: jq not installed"
    exit 1
fi

# Simple table header
printf "%-30s %-15s %-15s\n" "REPOSITORY" "REGISTRY STATUS" "WORKFLOW"
printf "%-30s %-15s %-15s\n" "$(printf '%.0s─' {1..30})" "$(printf '%.0s─' {1..15})" "$(printf '%.0s─' {1..15})"

# Check each repo
jq -r '.repositories[] | @json' config/repositories.json | while IFS= read -r repo_json; do
    name=$(echo "$repo_json" | jq -r '.name')
    status=$(echo "$repo_json" | jq -r '.status // "unknown"')
    url=$(echo "$repo_json" | jq -r '.url')

    # FIX: Validate and extract org/repo using regex (safer than sed)
    if [[ "$url" =~ ^https://github\.com/([a-zA-Z0-9_-]+)/([a-zA-Z0-9_-]+)$ ]]; then
        org="${BASH_REMATCH[1]}"
        repo="${BASH_REMATCH[2]}"
    else
        # Skip invalid URLs silently in quick check
        printf "%-30s %-25s %-25s\n" "$name" "$(echo -e "${RED}INVALID URL${NC}")" ""
        continue
    fi

    # Check if workflow exists
    if gh api "repos/${org}/${repo}/contents/.github/workflows/publish-upm.yml" >/dev/null 2>&1; then
        workflow_status="${GREEN}✅ EXISTS${NC}"
    else
        workflow_status="${RED}❌ MISSING${NC}"
    fi

    # Color status
    case $status in
        "active") status_color="${GREEN}$status${NC}" ;;
        "pending") status_color="${YELLOW}$status${NC}" ;;
        "disabled") status_color="${RED}$status${NC}" ;;
        *) status_color="$status" ;;
    esac

    printf "%-30s %-25s %-25s\n" "$name" "$(echo -e "$status_color")" "$(echo -e "$workflow_status")"
done

echo ""
echo "💡 Tip: Run './scripts/audit-repos.sh' for detailed analysis"
