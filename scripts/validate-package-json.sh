#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Validate package.json files using Gemini API
# Usage: ./validate-package-json.sh <repo_url> [package_path]

if [ -z "$1" ]; then
    echo "Usage: $0 <repo_url> [package_path]"
    echo "Example: $0 https://github.com/The1Studio/TheOne.FTUE"
    echo "Example: $0 https://github.com/The1Studio/TheOne.FTUE Sources"
    exit 1
fi

REPO_URL="$1"
PACKAGE_PATH="${2:-}"
GEMINI_API_KEY="${GEMINI_API_KEY:-}"

if [ -z "$GEMINI_API_KEY" ]; then
    echo -e "${RED}❌ GEMINI_API_KEY environment variable not set${NC}"
    exit 1
fi

# Extract repo name from URL
if [[ "$REPO_URL" =~ github\.com/([^/]+)/([^/]+) ]]; then
    REPO_OWNER="${BASH_REMATCH[1]}"
    REPO_NAME="${BASH_REMATCH[2]}"
else
    echo -e "${RED}❌ Invalid GitHub URL${NC}"
    exit 1
fi

REPO_FULL="$REPO_OWNER/$REPO_NAME"

echo -e "${GREEN}🔍 Validating package.json files in $REPO_FULL${NC}"
echo ""

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Clone repository
echo "📥 Cloning repository..."
if ! gh repo clone "$REPO_FULL" repo 2>&1; then
    echo -e "${RED}❌ Failed to clone repository${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

cd repo

# Find package.json files
if [ -n "$PACKAGE_PATH" ]; then
    PACKAGE_FILES=$(find "$PACKAGE_PATH" -name "package.json" -type f 2>/dev/null || echo "")
else
    PACKAGE_FILES=$(find . -name "package.json" -type f ! -path "*/node_modules/*" ! -path "*/.git/*" 2>/dev/null || echo "")
fi

if [ -z "$PACKAGE_FILES" ]; then
    echo -e "${YELLOW}⚠️  No package.json files found${NC}"
    rm -rf "$TEMP_DIR"
    exit 0
fi

# Validation rules for Gemini
VALIDATION_RULES=$(cat <<'EOF'
You are a Unity Package Manager (UPM) package.json validator. Analyze the provided package.json file and check for the following issues:

**Critical Issues (Must Fix):**
1. JSON syntax errors (missing commas, trailing commas, invalid characters)
2. Missing required fields: "name", "version", "displayName", "description", "unity"
3. Invalid semver format in "version" field
4. Invalid package name format (must match: com.company.package)
5. Duplicate keys in JSON object
6. Invalid dependency version formats

**Warning Issues (Should Fix):**
1. Missing recommended fields: "license", "author", "keywords"
2. Missing "publishConfig.registry" (optional but recommended)
3. Dependencies with "*" or "latest" versions (should use specific versions)
4. Very large description (>500 characters)
5. Missing or empty keywords array
6. Invalid Unity version format

**Response Format:**
Return ONLY a JSON object with this exact structure:
{
  "valid": true/false,
  "issues": [
    {
      "severity": "critical" | "warning",
      "type": "syntax_error" | "missing_field" | "invalid_format" | "recommendation",
      "field": "field_name",
      "message": "Clear description of the issue",
      "suggestion": "How to fix it (including exact code if applicable)"
    }
  ],
  "fixedContent": "ONLY if critical issues found, provide the complete fixed package.json content here",
  "summary": "One-line summary of findings"
}

If the file is valid with no issues, return: {"valid": true, "issues": [], "summary": "Package.json is valid"}

Do NOT include any markdown formatting, code blocks, or explanatory text outside the JSON object.
EOF
)

# Output file for issues
ISSUES_FILE="$TEMP_DIR/validation_issues.json"
echo "[]" > "$ISSUES_FILE"

# Validate each package.json
TOTAL_FILES=$(echo "$PACKAGE_FILES" | wc -l)
CURRENT=0
ISSUES_FOUND=0

echo -e "${GREEN}📋 Found $TOTAL_FILES package.json file(s) to validate${NC}"
echo ""

for PACKAGE_JSON in $PACKAGE_FILES; do
    CURRENT=$((CURRENT + 1))
    RELATIVE_PATH="${PACKAGE_JSON#./}"

    echo -e "${YELLOW}[$CURRENT/$TOTAL_FILES]${NC} Validating: $RELATIVE_PATH"

    # First, check if it's valid JSON
    if ! jq empty "$PACKAGE_JSON" 2>/dev/null; then
        echo -e "${RED}  ❌ Invalid JSON syntax${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))

        # Add to issues list
        jq --arg path "$RELATIVE_PATH" \
           --arg error "Invalid JSON syntax - cannot parse file" \
           '. += [{
               "path": $path,
               "valid": false,
               "issues": [{
                   "severity": "critical",
                   "type": "syntax_error",
                   "field": "entire_file",
                   "message": $error,
                   "suggestion": "Fix JSON syntax errors (missing/extra commas, quotes, brackets)"
               }],
               "summary": "JSON syntax error"
           }]' "$ISSUES_FILE" > "$ISSUES_FILE.tmp" && mv "$ISSUES_FILE.tmp" "$ISSUES_FILE"

        continue
    fi

    # Read package.json content
    PACKAGE_CONTENT=$(cat "$PACKAGE_JSON")

    # Create prompt for Gemini
    PROMPT=$(jq -n \
        --arg rules "$VALIDATION_RULES" \
        --arg content "$PACKAGE_CONTENT" \
        '{
            "contents": [{
                "parts": [{
                    "text": ($rules + "\n\nPackage.json to validate:\n\n" + $content)
                }]
            }],
            "generationConfig": {
                "temperature": 0.1,
                "maxOutputTokens": 2048
            }
        }')

    # Call Gemini API
    RESPONSE=$(curl -s -X POST \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=$GEMINI_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$PROMPT")

    # Extract the generated text
    GEMINI_OUTPUT=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // empty')

    if [ -z "$GEMINI_OUTPUT" ]; then
        echo -e "${RED}  ❌ Gemini API call failed${NC}"
        echo "  Response: $RESPONSE" | head -3
        continue
    fi

    # Remove markdown code blocks if present
    GEMINI_OUTPUT=$(echo "$GEMINI_OUTPUT" | sed 's/^```json$//' | sed 's/^```$//' | sed '/^$/d')

    # Parse Gemini response
    VALIDATION_RESULT=$(echo "$GEMINI_OUTPUT" | jq -r '.')

    if [ $? -ne 0 ]; then
        echo -e "${RED}  ❌ Failed to parse Gemini response${NC}"
        echo "  Output: $GEMINI_OUTPUT" | head -5
        continue
    fi

    # Check if valid
    IS_VALID=$(echo "$VALIDATION_RESULT" | jq -r '.valid')
    ISSUE_COUNT=$(echo "$VALIDATION_RESULT" | jq -r '.issues | length')
    SUMMARY=$(echo "$VALIDATION_RESULT" | jq -r '.summary')

    if [ "$IS_VALID" = "true" ] && [ "$ISSUE_COUNT" = "0" ]; then
        echo -e "${GREEN}  ✅ Valid - $SUMMARY${NC}"
    else
        echo -e "${RED}  ❌ Issues found - $SUMMARY${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))

        # Show issues
        echo "$VALIDATION_RESULT" | jq -r '.issues[] | "    • [\(.severity | ascii_upcase)] \(.message)"'

        # Add to issues list
        jq --arg path "$RELATIVE_PATH" \
           --argjson result "$VALIDATION_RESULT" \
           '. += [{
               "path": $path,
               "valid": $result.valid,
               "issues": $result.issues,
               "fixedContent": $result.fixedContent,
               "summary": $result.summary
           }]' "$ISSUES_FILE" > "$ISSUES_FILE.tmp" && mv "$ISSUES_FILE.tmp" "$ISSUES_FILE"
    fi

    echo ""
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}📊 Validation Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Total files checked: $TOTAL_FILES"
echo "  Files with issues: $ISSUES_FOUND"
echo "  Files valid: $((TOTAL_FILES - ISSUES_FOUND))"
echo ""

# Save results
cp "$ISSUES_FILE" "$TEMP_DIR/../validation_results.json"
echo "📄 Results saved to: $TEMP_DIR/../validation_results.json"

# Cleanup
cd /
rm -rf "$TEMP_DIR"

# Exit with error if issues found
if [ "$ISSUES_FOUND" -gt 0 ]; then
    exit 1
else
    exit 0
fi
