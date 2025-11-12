#!/bin/bash
set -euo pipefail

# Generate changelog entry using Gemini AI
# Usage: generate-changelog.sh <package_json_path> <old_version> <new_version> <gemini_api_key>

PACKAGE_JSON="$1"
OLD_VERSION="$2"
NEW_VERSION="$3"
GEMINI_API_KEY="$4"

PACKAGE_DIR=$(dirname "$PACKAGE_JSON")
CHANGELOG_FILE="$PACKAGE_DIR/CHANGELOG.md"
PACKAGE_NAME=$(jq -r '.name' "$PACKAGE_JSON")

echo "📝 Generating changelog for $PACKAGE_NAME: $OLD_VERSION → $NEW_VERSION"

# Function to call Gemini API with retry logic
call_gemini_api() {
  local prompt="$1"
  local max_retries=3
  local retry_delay=2

  for attempt in $(seq 1 $max_retries); do
    echo "🤖 Calling Gemini API (attempt $attempt/$max_retries)..."

    # Construct JSON request
    request_body=$(jq -n \
      --arg prompt "$prompt" \
      '{
        contents: [{
          parts: [{
            text: $prompt
          }]
        }],
        generationConfig: {
          temperature: 0.2,
          topP: 0.95,
          topK: 40,
          maxOutputTokens: 1024
        }
      }')

    # Make API call
    response=$(curl -s -X POST \
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=$GEMINI_API_KEY" \
      -H 'Content-Type: application/json' \
      -d "$request_body")

    # Check for errors
    if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
      error_msg=$(echo "$response" | jq -r '.error.message // "Unknown error"')
      echo "⚠️  API error: $error_msg"

      if [ "$attempt" -lt "$max_retries" ]; then
        echo "⏳ Retrying in ${retry_delay}s..."
        sleep $retry_delay
        retry_delay=$((retry_delay * 2))  # Exponential backoff
        continue
      else
        echo "❌ Max retries reached, API call failed"
        return 1
      fi
    fi

    # Extract generated text
    generated_text=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // ""')

    if [ -z "$generated_text" ]; then
      echo "⚠️  Empty response from API"

      if [ "$attempt" -lt "$max_retries" ]; then
        echo "⏳ Retrying in ${retry_delay}s..."
        sleep $retry_delay
        retry_delay=$((retry_delay * 2))
        continue
      else
        echo "❌ Max retries reached, empty response"
        return 1
      fi
    fi

    # Success
    echo "$generated_text"
    return 0
  done

  return 1
}

# Function to generate basic fallback changelog
generate_fallback_changelog() {
  local commits="$1"

  cat <<EOF
## [$NEW_VERSION] - $(date +%Y-%m-%d)

### Changed
EOF

  # Parse commits and group by conventional commit type
  echo "$commits" | while IFS= read -r commit; do
    echo "- $commit"
  done
}

# Get git commits since last version change in this package
echo "📊 Extracting git commits..."

# Find the commit where package.json was last changed with the old version
if [ "$OLD_VERSION" != "0.0.0" ]; then
  # Try to find when package.json had the old version
  last_version_commit=$(git log --all --format="%H" -- "$PACKAGE_JSON" | while read commit; do
    version=$(git show "$commit:$PACKAGE_JSON" 2>/dev/null | jq -r '.version // ""' 2>/dev/null || echo "")
    if [ "$version" = "$OLD_VERSION" ]; then
      echo "$commit"
      break
    fi
  done | head -n 1)

  if [ -n "$last_version_commit" ]; then
    # Get commits from that point to HEAD, in the package directory
    commits=$(git log --format="%s" "$last_version_commit..HEAD" -- "$PACKAGE_DIR" 2>/dev/null || echo "")
  else
    # Fallback: get recent commits in package directory
    commits=$(git log --format="%s" -n 20 -- "$PACKAGE_DIR" 2>/dev/null || echo "")
  fi
else
  # New package, get all commits
  commits=$(git log --format="%s" -n 20 -- "$PACKAGE_DIR" 2>/dev/null || echo "")
fi

if [ -z "$commits" ]; then
  echo "⚠️  No commits found, using generic changelog entry"
  commits="Initial version $NEW_VERSION"
fi

echo "Found $(echo "$commits" | wc -l) commits"

# Construct prompt for Gemini
read -r -d '' PROMPT <<EOF || true
You are a technical writer creating a CHANGELOG.md entry for a Unity package.

Package: $PACKAGE_NAME
Version: $OLD_VERSION → $NEW_VERSION

Git commits since last version:
$commits

Generate a changelog entry following the "Keep a Changelog" format (https://keepachangelog.com/).

Requirements:
1. Start with: ## [$NEW_VERSION] - $(date +%Y-%m-%d)
2. Use these sections ONLY if applicable: Added, Changed, Deprecated, Removed, Fixed, Security
3. Each item should be a concise, user-facing description (not commit messages verbatim)
4. Group related changes together
5. Use present tense ("Add" not "Added")
6. Focus on WHAT changed for users, not HOW it was implemented
7. If commits are unclear or minimal, create a reasonable summary
8. Do not include markdown code blocks, just the raw changelog text

Example format:
## [1.0.2] - 2025-01-16

### Fixed
- Fixed null reference exception in GetComponent method
- Resolved memory leak in coroutine cleanup

### Changed
- Improved Update loop performance by 30%

Generate the changelog entry now (do not include any explanations or extra text):
EOF

# Try to generate with AI
echo "🤖 Generating AI-powered changelog..."
ai_changelog=""

if [ -n "$GEMINI_API_KEY" ] && [ "$GEMINI_API_KEY" != "none" ]; then
  if ai_changelog=$(call_gemini_api "$PROMPT"); then
    echo "✅ AI generation successful"

    # Clean up the response (remove markdown code blocks if present)
    ai_changelog=$(echo "$ai_changelog" | sed 's/```markdown//g' | sed 's/```//g' | sed '/^$/d' | sed 's/^[[:space:]]*//')

  else
    echo "⚠️  AI generation failed, using fallback"
    ai_changelog=$(generate_fallback_changelog "$commits")
  fi
else
  echo "⚠️  No API key provided, using fallback"
  ai_changelog=$(generate_fallback_changelog "$commits")
fi

# Update or create CHANGELOG.md
echo "📄 Updating CHANGELOG.md..."

if [ -f "$CHANGELOG_FILE" ]; then
  # CHANGELOG exists, insert new version at the top
  echo "Updating existing CHANGELOG.md"

  # Create temporary file
  temp_file=$(mktemp)

  # Read existing file
  if grep -q "^# Changelog" "$CHANGELOG_FILE"; then
    # Has header, insert after header and any intro text, before first version
    awk -v new_entry="$ai_changelog" '
      /^## \[/ && !inserted {
        print new_entry
        print ""
        inserted=1
      }
      { print }
    ' "$CHANGELOG_FILE" > "$temp_file"
  else
    # No proper header, add header and entry
    {
      echo "# Changelog"
      echo ""
      echo "All notable changes to this package will be documented in this file."
      echo ""
      echo "The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)."
      echo ""
      echo "$ai_changelog"
      echo ""
      cat "$CHANGELOG_FILE"
    } > "$temp_file"
  fi

  mv "$temp_file" "$CHANGELOG_FILE"

else
  # Create new CHANGELOG
  echo "Creating new CHANGELOG.md"

  cat > "$CHANGELOG_FILE" <<EOF
# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

$ai_changelog
EOF
fi

echo "✅ Changelog generated successfully"
echo ""
echo "Generated entry:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$ai_changelog"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
