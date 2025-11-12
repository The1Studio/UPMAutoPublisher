#!/usr/bin/env bash
# validate-changelog.sh
# Validates CHANGELOG.md files follow Keep a Changelog format
# Usage: ./scripts/validate-changelog.sh <path_to_CHANGELOG.md>

set -eo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Valid section names per Keep a Changelog spec
VALID_SECTIONS=("Added" "Changed" "Deprecated" "Removed" "Fixed" "Security")

# Error tracking
ERRORS=0
WARNINGS=0

# Print functions
print_error() {
    echo -e "${RED}❌ Error: $1${NC}"
    ERRORS=$((ERRORS + 1))
}

print_warning() {
    echo -e "${YELLOW}⚠️  Warning: $1${NC}"
    WARNINGS=$((WARNINGS + 1))
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo "ℹ️  $1"
}

# Usage
usage() {
    cat <<EOF
Usage: $0 <path_to_CHANGELOG.md>

Validates CHANGELOG.md files follow Keep a Changelog format:
  - Proper header "# Changelog"
  - Version format: ## [X.Y.Z] - YYYY-MM-DD
  - Valid section names (Added, Changed, Deprecated, Removed, Fixed, Security)
  - ISO 8601 date format

Example:
  $0 CHANGELOG.md
  $0 path/to/CHANGELOG.md

Exit codes:
  0 - Valid changelog
  1 - Invalid changelog (errors found)
  2 - Warnings only (still valid)

EOF
    exit 1
}

# Check if file argument provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No file specified${NC}\n"
    usage
fi

# Check for help flag
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]] || [[ "$1" == "help" ]]; then
    usage
fi

CHANGELOG_FILE="$1"

echo "🔍 Validating CHANGELOG: $CHANGELOG_FILE"
echo ""

# Check if file exists
if [ ! -f "$CHANGELOG_FILE" ]; then
    print_error "File not found: $CHANGELOG_FILE"
    exit 1
fi

# Check if file is readable
if [ ! -r "$CHANGELOG_FILE" ]; then
    print_error "File not readable: $CHANGELOG_FILE"
    exit 1
fi

# Read file content
CONTENT=$(cat "$CHANGELOG_FILE")

# 1. Check for proper header
echo "📋 Checking header..."
FIRST_LINE=$(head -n1 "$CHANGELOG_FILE")
if [[ ! "$FIRST_LINE" =~ ^#[[:space:]]+[Cc]hangelog ]]; then
    print_error "Missing or invalid header. Expected '# Changelog' as first line, got: '$FIRST_LINE'"
else
    print_success "Header is valid"
fi
echo ""

# 2. Check for version entries
echo "🔢 Checking version entries..."
VERSION_COUNT=0
LINE_NUM=0

while IFS= read -r line; do
    LINE_NUM=$((LINE_NUM + 1))

    # Check for version headers (## [X.Y.Z] - YYYY-MM-DD)
    if [[ "$line" =~ ^##[[:space:]]+\[([0-9]+\.[0-9]+\.[0-9]+|Unreleased)\][[:space:]]*-[[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2})$ ]]; then
        VERSION="${BASH_REMATCH[1]}"
        DATE="${BASH_REMATCH[2]}"
        VERSION_COUNT=$((VERSION_COUNT + 1))

        # Validate semantic version format (skip Unreleased)
        if [[ "$VERSION" != "Unreleased" ]]; then
            if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                print_error "Line $LINE_NUM: Invalid version format '$VERSION'. Expected semantic version (X.Y.Z)"
            fi
        fi

        # Validate date format (YYYY-MM-DD)
        if [[ ! "$DATE" =~ ^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$ ]]; then
            print_error "Line $LINE_NUM: Invalid date format '$DATE'. Expected ISO 8601 format (YYYY-MM-DD)"
        else
            # Check if date is valid (e.g., not 2024-02-31)
            if ! date -d "$DATE" >/dev/null 2>&1; then
                print_error "Line $LINE_NUM: Invalid date '$DATE'. Date does not exist"
            fi
        fi

    # Check for malformed version headers
    elif [[ "$line" =~ ^##[[:space:]]+\[ ]]; then
        if [[ ! "$line" =~ -[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
            print_error "Line $LINE_NUM: Malformed version header. Missing or invalid date: '$line'"
        else
            print_error "Line $LINE_NUM: Malformed version header. Invalid format: '$line'"
            print_info "Expected format: ## [X.Y.Z] - YYYY-MM-DD"
        fi
    fi
done < "$CHANGELOG_FILE"

if [ $VERSION_COUNT -eq 0 ]; then
    print_warning "No version entries found. Expected at least one version entry"
else
    print_success "Found $VERSION_COUNT version entries"
fi
echo ""

# 3. Check for valid section names
echo "📑 Checking section names..."
SECTION_COUNT=0
INVALID_SECTIONS=()

LINE_NUM=0
while IFS= read -r line; do
    LINE_NUM=$((LINE_NUM + 1))

    # Check for section headers (### Section)
    if [[ "$line" =~ ^###[[:space:]]+(.+)$ ]]; then
        SECTION_NAME="${BASH_REMATCH[1]}"
        SECTION_COUNT=$((SECTION_COUNT + 1))

        # Check if section name is valid
        VALID=false
        for valid_section in "${VALID_SECTIONS[@]}"; do
            if [ "$SECTION_NAME" == "$valid_section" ]; then
                VALID=true
                break
            fi
        done

        if [ "$VALID" = false ]; then
            INVALID_SECTIONS+=("Line $LINE_NUM: '$SECTION_NAME'")
            print_error "Line $LINE_NUM: Invalid section name '$SECTION_NAME'. Valid sections: ${VALID_SECTIONS[*]}"
        fi
    fi
done < "$CHANGELOG_FILE"

if [ ${#INVALID_SECTIONS[@]} -eq 0 ] && [ $SECTION_COUNT -gt 0 ]; then
    print_success "All $SECTION_COUNT sections use valid names"
elif [ $SECTION_COUNT -eq 0 ]; then
    print_warning "No section headers found (###). Expected: ${VALID_SECTIONS[*]}"
fi
echo ""

# 4. Check for Unreleased section (recommended)
echo "🚀 Checking for Unreleased section..."
if echo "$CONTENT" | grep -q "^## \[Unreleased\]"; then
    print_success "Unreleased section found"
else
    print_warning "No [Unreleased] section found. Consider adding one for tracking upcoming changes"
fi
echo ""

# 5. Additional format checks
echo "🔧 Additional format checks..."

# Check for consistent indentation in lists
if echo "$CONTENT" | grep -q "^-[^ ]"; then
    print_warning "Found list items without space after dash (e.g., '-item' instead of '- item')"
fi

# Check for empty version sections
EMPTY_VERSIONS=$(awk '
    /^## \[/ {
        if (version && !content) {
            print version
        }
        version = $0
        content = 0
    }
    /^###/ {
        content = 1
    }
    END {
        if (version && !content) {
            print version
        }
    }
' "$CHANGELOG_FILE")
if [ -n "$EMPTY_VERSIONS" ]; then
    print_warning "Found version(s) with no sections:"
    echo "$EMPTY_VERSIONS" | while read -r line; do
        echo "    $line"
    done
fi

print_success "Format checks complete"
echo ""

# 6. Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Validation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "File: $CHANGELOG_FILE"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [ $ERRORS -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        print_success "Changelog is valid! ✨"
        echo ""
        exit 0
    else
        echo -e "${YELLOW}⚠️  Changelog is valid with $WARNINGS warning(s)${NC}"
        echo ""
        exit 2
    fi
else
    print_error "Changelog has $ERRORS error(s). Please fix them."
    echo ""
    echo "Resources:"
    echo "  - Keep a Changelog: https://keepachangelog.com/"
    echo "  - Format guide: https://keepachangelog.com/en/1.1.0/"
    echo ""
    exit 1
fi
