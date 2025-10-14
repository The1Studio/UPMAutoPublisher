#!/usr/bin/env bash
# setup-secrets.sh
# Script to set up Docker secrets for GitHub Actions runners
#
# This script creates the secrets directory and helps you securely
# configure your GitHub PAT without exposing it in environment variables.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_DIR="${SCRIPT_DIR}/.secrets"

echo "🔐 GitHub Actions Runner - Secrets Setup"
echo "========================================"
echo ""

# Create secrets directory
if [ ! -d "$SECRETS_DIR" ]; then
    echo "📁 Creating secrets directory..."
    mkdir -p "$SECRETS_DIR"
    chmod 700 "$SECRETS_DIR"
    echo "✅ Created: $SECRETS_DIR"
else
    echo "ℹ️  Secrets directory already exists: $SECRETS_DIR"
fi

# Check if secret file already exists
SECRET_FILE="${SECRETS_DIR}/github_pat"
if [ -f "$SECRET_FILE" ]; then
    echo ""
    echo "⚠️  Secret file already exists: $SECRET_FILE"
    read -rp "Do you want to overwrite it? (y/N): " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "❌ Aborted. Keeping existing secret file."
        exit 0
    fi
fi

# Prompt for GitHub PAT
echo ""
echo "📝 Please enter your GitHub Personal Access Token (PAT)"
echo ""
echo "Required scopes:"
echo "  - For organization runners: admin:org, repo"
echo "  - For repository runners: repo"
echo ""
echo "Create token at: https://github.com/settings/tokens"
echo ""
read -rsp "GitHub PAT: " github_pat
echo ""

# Validate input
if [ -z "$github_pat" ]; then
    echo "❌ Error: GitHub PAT cannot be empty"
    exit 1
fi

# Check if token looks valid (starts with ghp_ or github_pat_)
if [[ ! "$github_pat" =~ ^(ghp_|github_pat_) ]]; then
    echo "⚠️  Warning: Token format doesn't look valid"
    echo "   Valid tokens start with 'ghp_' or 'github_pat_'"
    read -rp "Continue anyway? (y/N): " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "❌ Aborted"
        exit 1
    fi
fi

# Write secret to file
echo "$github_pat" > "$SECRET_FILE"
chmod 600 "$SECRET_FILE"

echo ""
echo "✅ Secret file created: $SECRET_FILE"
echo "✅ File permissions set to 600 (owner read/write only)"
echo ""

# FIX ME-4: Validate token works with GitHub API
echo "🧪 Testing token with GitHub API..."
if curl -f -s -H "Authorization: token $github_pat" https://api.github.com/user > /dev/null 2>&1; then
    echo "✅ Token validated successfully with GitHub API"
else
    echo "❌ Token validation failed - token may be invalid or expired"
    echo "   The token was saved but may not work with GitHub"
    echo "   Please verify:"
    echo "   - Token has correct scopes (admin:org, repo)"
    echo "   - Token is not expired"
    echo "   - You have network connectivity to GitHub"
    read -rp "Continue anyway? (y/N): " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        rm -f "$SECRET_FILE"
        echo "❌ Aborted and removed invalid token file"
        exit 1
    fi
fi
echo ""

# Verify file
echo "🔍 Verifying secret file..."
if [ -f "$SECRET_FILE" ] && [ -r "$SECRET_FILE" ]; then
    file_size=$(wc -c < "$SECRET_FILE")
    echo "✅ File exists and is readable"
    echo "📏 File size: ${file_size} bytes"
else
    echo "❌ Error: Failed to create or read secret file"
    exit 1
fi

echo ""
echo "========================================="
echo "✅ Setup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Start runners: docker compose -f docker-compose.runners.yml up -d"
echo "2. Check logs: docker compose -f docker-compose.runners.yml logs -f"
echo "3. Verify runners appear in GitHub:"
echo "   https://github.com/organizations/The1Studio/settings/actions/runners"
echo ""
echo "⚠️  Security reminders:"
echo "- Never commit the .secrets/ directory"
echo "- Rotate this token annually"
echo "- Keep file permissions at 600"
echo ""
