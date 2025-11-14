#!/bin/bash
#
# Cleanup script to remove publish-upm.yml from registered repositories
# The Cloudflare webhook handles publishing organization-wide,
# so per-repository workflows are no longer needed.
#
# Usage: ./scripts/cleanup-repo-workflows.sh [--dry-run]
#

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "🔍 DRY RUN MODE - No actual changes will be made"
  echo
fi

# Read repositories from config
REPOS=$(jq -r '.[] | select(.status == "active") | .url | sub("https://github.com/"; "")' config/repositories.json)

if [[ -z "$REPOS" ]]; then
  echo "❌ No active repositories found in config/repositories.json"
  exit 1
fi

echo "📋 Found $(echo "$REPOS" | wc -l) active repositories"
echo

# Process each repository
for repo in $REPOS; do
  echo "🔄 Processing $repo..."

  # Clone to temp directory
  TEMP_DIR=$(mktemp -d)
  trap "rm -rf $TEMP_DIR" EXIT

  if ! git clone --depth 1 "git@github.com:$repo.git" "$TEMP_DIR" 2>/dev/null; then
    echo "  ⚠️  Failed to clone $repo (permission denied or repo doesn't exist)"
    continue
  fi

  cd "$TEMP_DIR"

  # Check if publish-upm.yml exists
  if [[ ! -f ".github/workflows/publish-upm.yml" ]]; then
    echo "  ✅ No publish-upm.yml found - already clean"
    cd - >/dev/null
    continue
  fi

  # Remove the workflow file
  if [[ "$DRY_RUN" == true ]]; then
    echo "  🔍 Would remove .github/workflows/publish-upm.yml"
  else
    git rm .github/workflows/publish-upm.yml

    # Commit and push
    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"

    git commit -m "chore: remove publish-upm.yml workflow

The Cloudflare webhook in UPMAutoPublisher now handles package detection
and publishing organization-wide. Per-repository workflows are no longer
needed.

See: https://github.com/The1Studio/UPMAutoPublisher"

    git push origin master || git push origin main

    echo "  ✅ Removed publish-upm.yml and pushed changes"
  fi

  cd - >/dev/null
done

echo
if [[ "$DRY_RUN" == true ]]; then
  echo "🔍 Dry run complete - no changes were made"
  echo "   Run without --dry-run to apply changes"
else
  echo "✅ Cleanup complete for all repositories"
fi
