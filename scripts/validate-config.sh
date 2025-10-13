#!/usr/bin/env bash
# validate-config.sh
# Validates config/repositories.json against schema

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔍 Validating config/repositories.json..."
echo ""

# Check if files exist
if [ ! -f "$PROJECT_ROOT/config/repositories.json" ]; then
    echo "❌ Error: config/repositories.json not found"
    exit 1
fi

if [ ! -f "$PROJECT_ROOT/config/schema.json" ]; then
    echo "❌ Error: config/schema.json not found"
    exit 1
fi

# Check if ajv-cli is installed
if ! command -v ajv &>/dev/null; then
    echo "📦 ajv-cli not found, installing..."
    if command -v npm &>/dev/null; then
        npm install -g ajv-cli ajv-formats
    else
        echo "❌ Error: npm not found. Please install Node.js and npm."
        exit 1
    fi
fi

# Validate JSON syntax first
if ! jq empty "$PROJECT_ROOT/config/repositories.json" 2>/dev/null; then
    echo "❌ JSON syntax error in repositories.json"
    echo ""
    echo "Details:"
    jq empty "$PROJECT_ROOT/config/repositories.json"
    exit 1
fi

echo "✅ JSON syntax is valid"
echo ""

# Validate against schema
if ajv validate \
    -s "$PROJECT_ROOT/config/schema.json" \
    -d "$PROJECT_ROOT/config/repositories.json" \
    --strict=false \
    2>&1; then
    echo ""
    echo "✅ config/repositories.json is valid!"
    echo ""

    # Show summary
    total_repos=$(jq '.repositories | length' "$PROJECT_ROOT/config/repositories.json")
    active_repos=$(jq '[.repositories[] | select(.status == "active")] | length' "$PROJECT_ROOT/config/repositories.json")
    pending_repos=$(jq '[.repositories[] | select(.status == "pending")] | length' "$PROJECT_ROOT/config/repositories.json")
    disabled_repos=$(jq '[.repositories[] | select(.status == "disabled")] | length' "$PROJECT_ROOT/config/repositories.json")

    echo "📊 Repository Summary:"
    echo "   Total: $total_repos"
    echo "   Active: $active_repos"
    echo "   Pending: $pending_repos"
    echo "   Disabled: $disabled_repos"
    echo ""

    exit 0
else
    echo ""
    echo "❌ Validation failed!"
    echo ""
    echo "Common issues:"
    echo "  - Missing required fields (name, url, packages, status)"
    echo "  - Invalid status value (must be: active, pending, or disabled)"
    echo "  - Invalid package name format (must start with com.theone.)"
    echo "  - Invalid URL format"
    echo ""
    echo "See config/schema.json for full schema definition"
    exit 1
fi
