#!/usr/bin/env bash
# build-package-cache.sh
# Builds minimal package cache with version tracking
# Scans all registered repositories and caches package locations and versions

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

CACHE_FILE="config/package-cache.json"
REGISTRY="https://upm.the1studio.org/"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔨 Building Package Cache"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check prerequisites
if [ ! -f "config/repositories.json" ]; then
  echo "${CROSS} Error: config/repositories.json not found"
  echo "Please run this script from the UPMAutoPublisher root directory"
  exit 1
fi

if ! command -v gh &>/dev/null; then
  echo "${CROSS} Error: GitHub CLI (gh) is not installed"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "${CROSS} Error: jq is not installed"
  exit 1
fi

if ! gh auth status &>/dev/null; then
  echo "${CROSS} Error: Not authenticated with GitHub"
  echo "Run: gh auth login"
  exit 1
fi

echo "Prerequisites: ${CHECK} All dependencies available"
echo ""

# Initialize cache with empty repositories object
jq -n '{
  updated: (now | todate),
  repositories: {}
}' > "$CACHE_FILE.tmp"

# Counters
total_packages=0
total_repos=0
skipped_repos=0

echo "Scanning repositories..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Process each repository
while IFS= read -r repo_json; do
  # Skip empty lines
  [ -z "$repo_json" ] && continue

  total_repos=$((total_repos + 1))

  url=$(echo "$repo_json" | jq -r '.url')
  status=$(echo "$repo_json" | jq -r '.status')

  # Skip disabled repos
  if [ "$status" = "disabled" ]; then
    echo "⏭️  Skipping disabled: $url"
    skipped_repos=$((skipped_repos + 1))
    continue
  fi

  # Extract org/repo using regex
  if [[ "$url" =~ ^https://github\.com/([a-zA-Z0-9_-]+)/([a-zA-Z0-9._-]+)$ ]]; then
    org="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
  else
    echo "${CROSS} Invalid URL: $url"
    skipped_repos=$((skipped_repos + 1))
    continue
  fi

  echo "${BLUE}Repository:${NC} $org/$repo"

  # Check if repository is accessible
  if ! gh repo view "$org/$repo" &>/dev/null; then
    echo "  ${CROSS} Repository not accessible"
    skipped_repos=$((skipped_repos + 1))
    echo ""
    continue
  fi

  # Find all package.json files
  echo "  🔍 Finding package.json files..."
  package_files=$(gh api "repos/$org/$repo/git/trees/master?recursive=1" \
    --jq '.tree[] | select(.path | endswith("package.json")) | "\(.path)|\(.sha)"' \
    2>/dev/null || echo "")

  if [ -z "$package_files" ]; then
    echo "  ${WARN} No package.json files found"
    echo ""
    continue
  fi

  # Process each package.json
  while IFS='|' read -r pkg_path pkg_sha; do
    # Skip node_modules and hidden directories
    if [[ "$pkg_path" =~ node_modules|/\. ]]; then
      continue
    fi

    echo "  📦 Processing: $pkg_path"

    # Read package.json content
    pkg_content=$(gh api "repos/$org/$repo/contents/$pkg_path" \
      --jq '.content' 2>/dev/null | base64 -d 2>/dev/null || echo "")

    if [ -z "$pkg_content" ]; then
      echo "     ${CROSS} Failed to read package.json"
      continue
    fi

    # Extract package name and version
    pkg_name=$(echo "$pkg_content" | jq -r '.name // empty')
    current_version=$(echo "$pkg_content" | jq -r '.version // empty')

    if [ -z "$pkg_name" ] || [ -z "$current_version" ]; then
      echo "     ${WARN} Invalid package.json (missing name or version)"
      continue
    fi

    # Check published version on registry
    published_version=$(npm view "$pkg_name" version --registry "$REGISTRY" 2>/dev/null || echo "")

    if [ -z "$published_version" ]; then
      echo "     Current: $current_version"
      echo "     Published: ${YELLOW}not-published${NC}"
    elif [ "$current_version" = "$published_version" ]; then
      echo "     ${CHECK} $current_version (up-to-date)"
    else
      echo "     Current: $current_version"
      echo "     Published: $published_version"
      echo "     Status: ${YELLOW}stale${NC}"
    fi

    # Add to cache grouped by repository
    jq --arg repo_key "$org/$repo" \
       --arg pkg_name "$pkg_name" \
       --arg path "$pkg_path" \
       --arg version "$current_version" \
       --arg publishedVersion "${published_version:-null}" \
       '.repositories[$repo_key].packages[$pkg_name] = {
         path: $path,
         version: $version,
         publishedVersion: (if $publishedVersion == "null" or $publishedVersion == "" then null else $publishedVersion end)
       }' "$CACHE_FILE.tmp" > "$CACHE_FILE.tmp2"

    mv "$CACHE_FILE.tmp2" "$CACHE_FILE.tmp"

    total_packages=$((total_packages + 1))

  done <<< "$package_files"

  echo ""
  sleep 0.5  # Rate limit protection

done < <(jq -c '.repositories[]' config/repositories.json)

# Move temp file to final location
mv "$CACHE_FILE.tmp" "$CACHE_FILE"

# Generate statistics
uptodate=$(jq '[.repositories | to_entries[] | .value.packages | to_entries[] | select(.value.version == .value.publishedVersion)] | length' "$CACHE_FILE")
stale=$(jq '[.repositories | to_entries[] | .value.packages | to_entries[] | select(.value.version != .value.publishedVersion and .value.publishedVersion != null)] | length' "$CACHE_FILE")
new=$(jq '[.repositories | to_entries[] | .value.packages | to_entries[] | select(.value.publishedVersion == null)] | length' "$CACHE_FILE")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Cache Build Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Repositories:"
echo "  Total scanned: $total_repos"
echo "  Skipped: $skipped_repos"
echo ""
echo "Packages:"
echo "  Total cached: $total_packages"
echo "  ${CHECK} Up-to-date: $uptodate"
echo "  ${WARN} Stale (needs publish): $stale"
echo "  📦 New (not published): $new"
echo ""
echo "Cache file: $CACHE_FILE"
echo "Last updated: $(jq -r '.updated' "$CACHE_FILE")"
echo ""

if [ "$stale" -gt 0 ]; then
  echo "${WARN} Stale packages found:"
  jq -r '.repositories | to_entries[] | .key as $repo | .value.packages | to_entries[] | select(.value.version != .value.publishedVersion and .value.publishedVersion != null) | "  - \(.key) (\($repo)): \(.value.version) (published: \(.value.publishedVersion))"' "$CACHE_FILE"
  echo ""
fi

echo "✅ Cache built successfully!"
