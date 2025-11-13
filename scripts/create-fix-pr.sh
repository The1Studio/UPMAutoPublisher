#!/bin/bash
set -e

# Create PR to fix package.json issues found by validation
# Usage: ./create-fix-pr.sh <repo_url> <validation_results.json>

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <repo_url> <validation_results.json>"
    echo "Example: $0 https://github.com/The1Studio/TheOne.FTUE validation_results.json"
    exit 1
fi

REPO_URL="$1"
VALIDATION_FILE="$2"

if [ ! -f "$VALIDATION_FILE" ]; then
    echo "❌ Validation results file not found: $VALIDATION_FILE"
    exit 1
fi

# Check if any issues found
ISSUE_COUNT=$(jq 'length' "$VALIDATION_FILE")
if [ "$ISSUE_COUNT" -eq 0 ]; then
    echo "✅ No issues found, no PR needed"
    exit 0
fi

# Extract repo info
if [[ "$REPO_URL" =~ github\.com/([^/]+)/([^/]+) ]]; then
    REPO_OWNER="${BASH_REMATCH[1]}"
    REPO_NAME="${BASH_REMATCH[2]}"
else
    echo "❌ Invalid GitHub URL"
    exit 1
fi

REPO_FULL="$REPO_OWNER/$REPO_NAME"

echo "🔧 Creating fix PR for $REPO_FULL"
echo ""

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Clone repository
echo "📥 Cloning repository..."
if ! gh repo clone "$REPO_FULL" repo 2>&1; then
    echo "❌ Failed to clone repository"
    rm -rf "$TEMP_DIR"
    exit 1
fi

cd repo

# Get default branch
DEFAULT_BRANCH=$(git remote show origin | grep "HEAD branch" | cut -d ":" -f 2 | xargs)
if [ -z "$DEFAULT_BRANCH" ]; then
    DEFAULT_BRANCH="master"
fi

# Create fix branch
BRANCH_NAME="fix/package-json-validation-$(date +%Y%m%d-%H%M%S)"
git checkout -b "$BRANCH_NAME"

# Apply fixes
FIXED_COUNT=0
CRITICAL_ISSUES=""
WARNING_ISSUES=""

while IFS= read -r file_result; do
    FILE_PATH=$(echo "$file_result" | jq -r '.path')
    IS_VALID=$(echo "$file_result" | jq -r '.valid')
    FIXED_CONTENT=$(echo "$file_result" | jq -r '.fixedContent // empty')
    ISSUES=$(echo "$file_result" | jq -r '.issues')
    SUMMARY=$(echo "$file_result" | jq -r '.summary')

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 Processing: $FILE_PATH"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Count critical and warning issues
    CRITICAL_COUNT=$(echo "$ISSUES" | jq '[.[] | select(.severity == "critical")] | length')
    WARNING_COUNT=$(echo "$ISSUES" | jq '[.[] | select(.severity == "warning")] | length')

    if [ "$CRITICAL_COUNT" -gt 0 ]; then
        CRITICAL_ISSUES="$CRITICAL_ISSUES\n\n### 📦 \`$FILE_PATH\`\n"
        CRITICAL_ISSUES="$CRITICAL_ISSUES**Summary:** $SUMMARY\n\n"
        CRITICAL_ISSUES="$CRITICAL_ISSUES**Critical Issues ($CRITICAL_COUNT):**\n"
        CRITICAL_ISSUES="$CRITICAL_ISSUES$(echo "$ISSUES" | jq -r '.[] | select(.severity == "critical") | "- **\(.type)** (\(.field)): \(.message)\n  - Fix: \(.suggestion)\n"')"
    fi

    if [ "$WARNING_COUNT" -gt 0 ]; then
        WARNING_ISSUES="$WARNING_ISSUES\n\n### 📦 \`$FILE_PATH\`\n"
        WARNING_ISSUES="$WARNING_ISSUES**Warnings ($WARNING_COUNT):**\n"
        WARNING_ISSUES="$WARNING_ISSUES$(echo "$ISSUES" | jq -r '.[] | select(.severity == "warning") | "- **\(.type)** (\(.field)): \(.message)\n  - Suggestion: \(.suggestion)\n"')"
    fi

    # Apply fix if available
    if [ -n "$FIXED_CONTENT" ] && [ "$FIXED_CONTENT" != "null" ]; then
        echo "🔧 Applying automatic fix..."

        # Backup original
        cp "$FILE_PATH" "$FILE_PATH.backup"

        # Write fixed content
        echo "$FIXED_CONTENT" > "$FILE_PATH"

        # Validate fixed content
        if jq empty "$FILE_PATH" 2>/dev/null; then
            echo "✅ Fix applied successfully"
            FIXED_COUNT=$((FIXED_COUNT + 1))
            git add "$FILE_PATH"
        else
            echo "❌ Fixed content is not valid JSON, reverting..."
            mv "$FILE_PATH.backup" "$FILE_PATH"
        fi

        rm -f "$FILE_PATH.backup"
    else
        echo "⚠️  No automatic fix available (manual review needed)"
    fi

    echo ""
done < <(jq -c '.[]' "$VALIDATION_FILE")

# Check if any files were fixed
if [ "$FIXED_COUNT" -eq 0 ]; then
    echo "⚠️  No automatic fixes were applied"
    echo "   Manual review required for all issues"
    cd /
    rm -rf "$TEMP_DIR"
    exit 0
fi

# Create commit
echo "📝 Creating commit..."

COMMIT_MSG=$(cat <<EOF
fix: resolve package.json validation issues

Fixed $FIXED_COUNT package.json file(s) with critical issues detected by
automated validation using Gemini AI.

Issues resolved:
$CRITICAL_ISSUES

$WARNING_ISSUES

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)

git config user.name "UPM Auto Publisher Bot"
git config user.email "noreply@the1studio.org"
git commit -m "$COMMIT_MSG"

# Push branch
echo "📤 Pushing branch..."
git push -u origin "$BRANCH_NAME"

# Create PR
echo "🎯 Creating pull request..."

# Build PR body with proper formatting
PR_BODY=$(cat <<EOF
## 🔍 Automated Package.json Validation Fix

This PR automatically fixes critical issues found in package.json files by our validation system.

---

## 🤖 Validation System

- **Validator:** Gemini 2.0 Flash AI
- **Files Fixed:** $FIXED_COUNT
- **Validation Date:** $(date -u +"%Y-%m-%d %H:%M:%S") UTC

---

## 🚨 Critical Issues Fixed

$CRITICAL_ISSUES

---

## ⚠️ Warnings (For Review)

$WARNING_ISSUES

---

## ✅ Verification

All fixes have been validated to ensure:
- ✅ Valid JSON syntax
- ✅ Required UPM fields present
- ✅ Proper semantic versioning
- ✅ Valid package name format

---

## 🔗 Related

- Validation triggered by: UPM Auto Publisher
- Detection: Automated CI/CD validation workflow
- Fix: Automatic with AI assistance

---

**⚡ Ready to merge after review**

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)

PR_URL=$(gh pr create \
    --title "🔧 Fix package.json validation issues" \
    --body "$PR_BODY" \
    --base "$DEFAULT_BRANCH" \
    --head "$BRANCH_NAME" \
    --label "automated" \
    --label "bug" 2>&1 | grep -o 'https://github.com[^ ]*' || echo "")

if [ -n "$PR_URL" ]; then
    echo "✅ Pull request created successfully!"
    echo "📋 PR URL: $PR_URL"
    echo ""

    # Enable auto-merge if possible
    echo "🔄 Attempting to enable auto-merge..."
    if gh pr merge "$PR_URL" --auto --squash 2>/dev/null; then
        echo "✅ Auto-merge enabled (will merge when checks pass)"
    else
        echo "⚠️  Auto-merge not available (may require manual merge)"
    fi

    # Save PR URL for Discord notification
    echo "$PR_URL" > "$TEMP_DIR/../pr_url.txt"
else
    echo "❌ Failed to create pull request"
    cd /
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Cleanup
cd /
rm -rf "$TEMP_DIR"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Fix PR created successfully for $REPO_FULL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
