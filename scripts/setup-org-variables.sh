#!/bin/bash
# Setup all UPMAutoPublisher organization variables
# This script creates 14 organization variables to eliminate hardcoded values

set -e

ORG="The1Studio"

echo "🔧 Setting up organization variables for $ORG..."
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed"
    echo "Install: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub CLI"
    echo "Run: gh auth login"
    exit 1
fi

echo "📋 Creating Discord configuration variables..."

# Discord Thread IDs
gh variable set DISCORD_THREAD_PACKAGES \
  --body "1437635998509957181" \
  --org $ORG && echo "  ✅ DISCORD_THREAD_PACKAGES"

gh variable set DISCORD_THREAD_MONITORING \
  --body "1437635908781342783" \
  --org $ORG && echo "  ✅ DISCORD_THREAD_MONITORING"

# Discord Visual Assets
gh variable set DISCORD_ICON_NPM \
  --body "https://raw.githubusercontent.com/github/explore/80688e429a7d4ef2fca1e82350fe8e3517d3494d/topics/npm/npm.png" \
  --org $ORG && echo "  ✅ DISCORD_ICON_NPM"

gh variable set DISCORD_ICON_STUDIO \
  --body "https://raw.githubusercontent.com/The1Studio/UPMAutoPublisher/master/.github/assets/the1studio-logo.png" \
  --org $ORG && echo "  ✅ DISCORD_ICON_STUDIO"

# Discord Colors
gh variable set DISCORD_COLOR_SUCCESS \
  --body "4764443" \
  --org $ORG && echo "  ✅ DISCORD_COLOR_SUCCESS"

gh variable set DISCORD_COLOR_FAILURE \
  --body "15158332" \
  --org $ORG && echo "  ✅ DISCORD_COLOR_FAILURE"

gh variable set DISCORD_COLOR_WARNING \
  --body "16776960" \
  --org $ORG && echo "  ✅ DISCORD_COLOR_WARNING"

echo ""
echo "📋 Creating Gemini API configuration variables..."

# Gemini API Configuration
gh variable set GEMINI_TEMP_CHANGELOG \
  --body "0.2" \
  --org $ORG && echo "  ✅ GEMINI_TEMP_CHANGELOG"

gh variable set GEMINI_TEMP_VALIDATION \
  --body "0.1" \
  --org $ORG && echo "  ✅ GEMINI_TEMP_VALIDATION"

gh variable set GEMINI_TOKENS_CHANGELOG \
  --body "1024" \
  --org $ORG && echo "  ✅ GEMINI_TOKENS_CHANGELOG"

gh variable set GEMINI_TOKENS_VALIDATION \
  --body "2048" \
  --org $ORG && echo "  ✅ GEMINI_TOKENS_VALIDATION"

echo ""
echo "📋 Creating workflow timeout variables..."

# Workflow Timeouts
gh variable set TIMEOUT_DEFAULT \
  --body "30" \
  --org $ORG && echo "  ✅ TIMEOUT_DEFAULT"

gh variable set TIMEOUT_VALIDATION \
  --body "60" \
  --org $ORG && echo "  ✅ TIMEOUT_VALIDATION"

gh variable set TIMEOUT_QUICK \
  --body "10" \
  --org $ORG && echo "  ✅ TIMEOUT_QUICK"

echo ""
echo "✅ All organization variables set successfully!"
echo ""

# Verify variables
echo "📋 Verifying variables..."
echo ""
gh variable list --org $ORG | grep -E "DISCORD|GEMINI|TIMEOUT" || echo "⚠️  No variables found (may need org admin permissions)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Verify all 14 variables are listed above"
echo "2. Test composite actions: .github/actions/*/action.yml"
echo "3. Begin workflow refactoring (see docs/refactoring-plan.md)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
