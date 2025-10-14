#!/usr/bin/env bash
# audit-repos.sh
# Comprehensive UPM workflow audit script
# Checks all registered repositories and verifies their actual state

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Emojis
CHECK="✅"
CROSS="❌"
WARN="⚠️"
INFO="ℹ️"
PENDING="⏳"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 UPM Auto Publisher - Repository Audit"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if we're in the right directory
if [ ! -f "config/repositories.json" ]; then
    echo "${CROSS} Error: config/repositories.json not found"
    echo "Please run this script from the UPMAutoPublisher root directory"
    exit 1
fi

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "${CROSS} Error: GitHub CLI (gh) is not installed"
    echo "Install it: https://cli.github.com/"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "${CROSS} Error: jq is not installed"
    echo "Install it: sudo apt-get install jq"
    exit 1
fi

# Check GitHub authentication
if ! gh auth status &> /dev/null; then
    echo "${CROSS} Error: Not authenticated with GitHub"
    echo "Run: gh auth login"
    exit 1
fi

echo "Prerequisites check: ${CHECK} All dependencies available"
echo ""

# Statistics counters
total_repos=0
active_repos=0
pending_repos=0
disabled_repos=0
matched_repos=0
mismatched_repos=0

# FIX MAJOR-3: Create temporary file with explicit secure permissions
recommendations_file=$(mktemp)
chmod 600 "$recommendations_file"

# Ensure cleanup on exit
trap 'rm -f "$recommendations_file"' EXIT ERR INT TERM

echo "Scanning repositories..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# FIX: Function to check GitHub API rate limit
check_rate_limit() {
    local remaining=$(gh api rate_limit --jq '.rate.remaining' 2>/dev/null || echo "5000")
    local reset=$(gh api rate_limit --jq '.rate.reset' 2>/dev/null || echo "0")
    local current_time=$(date +%s)

    if [ "$remaining" -lt 100 ]; then
        local wait_time=$((reset - current_time))
        if [ "$wait_time" -gt 0 ]; then
            echo "⚠️  Approaching GitHub API rate limit ($remaining requests remaining)"
            echo "   Waiting ${wait_time}s until reset..."
            sleep "$wait_time"
        fi
    fi
}

# Process each repository
# FIX: Use process substitution instead of pipe to avoid subshell issue with counters
while IFS= read -r repo_json; do
    ((total_repos++))

    # FIX: Check rate limit before expensive operations
    check_rate_limit

    # Extract repository info
    name=$(echo "$repo_json" | jq -r '.name')
    status=$(echo "$repo_json" | jq -r '.status // "unknown"')
    url=$(echo "$repo_json" | jq -r '.url')
    package_count=$(echo "$repo_json" | jq '.packages | length')

    # FIX: Validate and extract org/repo using regex (safer than sed)
    if [[ "$url" =~ ^https://github\.com/([a-zA-Z0-9_-]+)/([a-zA-Z0-9_-]+)$ ]]; then
        org="${BASH_REMATCH[1]}"
        repo="${BASH_REMATCH[2]}"
    else
        echo "  ${CROSS} ${RED}Invalid URL format: $url${NC}"
        echo ""
        continue
    fi

    echo "${BLUE}Repository:${NC} $name"
    echo "  URL: $url"
    echo "  Registry Status: $status"
    echo "  Packages: $package_count"

    # Count by status
    case $status in
        "active") ((active_repos++)) ;;
        "pending") ((pending_repos++)) ;;
        "disabled") ((disabled_repos++)) ;;
    esac

    # Check if repository exists and is accessible
    if ! gh repo view "$url" &> /dev/null; then
        echo "  ${CROSS} ${RED}Repository not accessible${NC}"
        echo "  ${WARN} RECOMMENDATION: Check repository URL and permissions" >> "$recommendations_file"
        echo "      - Repository: $name" >> "$recommendations_file"
        echo "      - URL: $url" >> "$recommendations_file"
        echo ""
        continue
    fi

    echo "  ${CHECK} Repository accessible"

    # Check if workflow file exists
    if gh api "repos/${org}/${repo}/contents/.github/workflows/publish-upm.yml" >/dev/null 2>&1; then
        workflow_exists=true
        echo "  ${CHECK} ${GREEN}Workflow file exists${NC}"

        # Get workflow details
        workflow_state=$(gh api "repos/${org}/${repo}/actions/workflows/publish-upm.yml" 2>/dev/null | jq -r '.state // "unknown"')
        echo "      State: $workflow_state"

        # Get workflow run count
        run_count=$(gh api "repos/${org}/${repo}/actions/workflows/publish-upm.yml/runs?per_page=1" 2>/dev/null | jq '.total_count // 0')
        echo "      Total runs: $run_count"

        # Get last run status if exists
        if [ "$run_count" -gt 0 ]; then
            last_run=$(gh api "repos/${org}/${repo}/actions/workflows/publish-upm.yml/runs?per_page=1" 2>/dev/null | jq -r '.workflow_runs[0]')
            last_status=$(echo "$last_run" | jq -r '.conclusion // "running"')
            last_date=$(echo "$last_run" | jq -r '.created_at' | cut -d'T' -f1)

            case $last_status in
                "success") echo "      Last run: ${CHECK} success ($last_date)" ;;
                "failure") echo "      Last run: ${CROSS} failure ($last_date)" ;;
                "cancelled") echo "      Last run: ${WARN} cancelled ($last_date)" ;;
                *) echo "      Last run: ${INFO} $last_status ($last_date)" ;;
            esac
        else
            echo "      ${INFO} No runs yet"
        fi
    else
        workflow_exists=false
        echo "  ${CROSS} ${RED}Workflow file missing${NC}"
    fi

    # Compare registry status vs actual state
    echo ""
    echo "  ${BLUE}Status Analysis:${NC}"

    if [ "$status" = "active" ] && [ "$workflow_exists" = true ]; then
        echo "  ${CHECK} ${GREEN}MATCHED${NC} - Registry 'active' and workflow exists"
        ((matched_repos++))
    elif [ "$status" = "pending" ] && [ "$workflow_exists" = false ]; then
        echo "  ${PENDING} ${YELLOW}EXPECTED${NC} - Registry 'pending' and workflow not deployed yet"
        echo "  ${INFO} Next push to config/repositories.json will trigger deployment"
        ((matched_repos++))
    elif [ "$status" = "disabled" ]; then
        echo "  ${INFO} ${YELLOW}DISABLED${NC} - Repository intentionally disabled"
        if [ "$workflow_exists" = true ]; then
            echo "      (Note: Workflow file still exists but status is 'disabled')"
        fi
        ((matched_repos++))
    elif [ "$status" = "active" ] && [ "$workflow_exists" = false ]; then
        echo "  ${CROSS} ${RED}MISMATCH!${NC} - Registry says 'active' but workflow missing"
        echo "  ${WARN} RECOMMENDATION: Update status to 'pending' to trigger deployment" >> "$recommendations_file"
        echo "      - Repository: $name" >> "$recommendations_file"
        echo "      - Current status: active" >> "$recommendations_file"
        echo "      - Action: Change to 'pending' or deploy manually" >> "$recommendations_file"
        ((mismatched_repos++))
    elif [ "$status" = "pending" ] && [ "$workflow_exists" = true ]; then
        echo "  ${WARN} ${YELLOW}MISMATCH${NC} - Workflow exists but status is 'pending'"
        echo "  ${WARN} RECOMMENDATION: Update status to 'active'" >> "$recommendations_file"
        echo "      - Repository: $name" >> "$recommendations_file"
        echo "      - Current status: pending" >> "$recommendations_file"
        echo "      - Action: Change to 'active' (workflow already deployed)" >> "$recommendations_file"
        ((mismatched_repos++))
    else
        echo "  ${WARN} ${YELLOW}UNKNOWN STATE${NC}"
        ((mismatched_repos++))
    fi

    # Check package.json configuration
    echo ""
    echo "  ${BLUE}Package Configuration:${NC}"
    echo "$repo_json" | jq -r '.packages[] | "    - \(.name) at \(.path)"'

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # FIX: Small delay between repos to be nice to GitHub API
    sleep 0.5
done < <(jq -c '.repositories[]' config/repositories.json)

# Print summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Audit Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Total Repositories: $total_repos"
echo ""
echo "By Status:"
echo "  Active:   $active_repos"
echo "  Pending:  $pending_repos"
echo "  Disabled: $disabled_repos"
echo ""
echo "Verification:"
echo "  ${CHECK} Matched:    $matched_repos"
echo "  ${CROSS} Mismatched: $mismatched_repos"
echo ""

# Show recommendations if any
if [ -s "$recommendations_file" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "${WARN} Recommendations"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    cat "$recommendations_file"
    echo ""
fi

# Cleanup
rm -f "$recommendations_file"

# Exit status
if [ "$mismatched_repos" -gt 0 ]; then
    echo "${WARN} Audit completed with issues - review recommendations above"
    exit 1
else
    echo "${CHECK} Audit completed successfully - all repositories in sync"
    exit 0
fi
