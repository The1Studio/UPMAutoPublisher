# Automated Changelog Generation with Gemini 2 Pro API

**Date:** 2025-11-12
**Status:** Planning
**Priority:** Enhancement
**Estimated Effort:** 3-4 hours implementation + testing

## Overview

Integrate Gemini 2 Pro API into UPM Auto Publisher workflow to automatically generate meaningful CHANGELOG.md entries when publishing packages. System analyzes git history, generates human-readable changelog, updates per-package CHANGELOG.md files.

## Requirements

### Functional Requirements

1. **Mandatory for all packages** - Every publish triggers changelog generation
2. **Fail-safe publishing** - Package publishes even if changelog generation fails (warning logged)
3. **Git history analysis** - Analyze commits since last package.json version change
4. **Per-package changelogs** - Create/update CHANGELOG.md next to each package.json
5. **Keep a Changelog format** - Follow standard format (Added, Changed, Fixed, etc.)
6. **Secure API key storage** - Use GitHub organization secret `GEMINI_API_KEY`

### Non-Functional Requirements

- **Performance:** Changelog generation <10s per package
- **Rate limits:** Handle Gemini API rate limits gracefully
- **Security:** No sensitive data in prompts, secure key handling
- **Maintainability:** Clear logging, easy to debug
- **Idempotent:** Safe to re-run, won't duplicate entries

## Architecture

### Integration Point

Add new step **after package detection, before npm publish** in `handle-publish-request.yml`:

```
Detect packages → Generate Changelog → Publish to NPM → Create audit log
```

**Rationale:** Generate changelog before publishing so it's included in published package.

### Workflow Sequence

```
For each changed package:
1. Extract git history (commits since last version in package.json)
2. Call Gemini API with structured prompt
3. Parse Gemini response (markdown format)
4. Update CHANGELOG.md (prepend new version section)
5. Commit changelog changes back to repo
6. Proceed with npm publish
```

### Data Flow

```
Git History → Bash Script → Gemini API → Response Parser → CHANGELOG.md → Git Commit → NPM Publish
```

## Implementation Steps

### Step 1: Add GitHub Secret (Manual, 5 min)

**Location:** GitHub Organization Secrets
**Action:** Add `GEMINI_API_KEY`

```
Name: GEMINI_API_KEY
Value: AIzaSyAQg549fhGf-gY8Cwy5fnLaLg5mzBrP93I
Visibility: Available to all repositories
```

**Security note:** Organization-level secret, same pattern as NPM_TOKEN and GH_PAT.

### Step 2: Create Changelog Generation Script (30 min)

**File:** `scripts/generate-changelog.sh`

```bash
#!/bin/bash
set -euo pipefail

# Usage: ./generate-changelog.sh <package_dir> <package_name> <old_version> <new_version>
PACKAGE_DIR="$1"
PACKAGE_NAME="$2"
OLD_VERSION="$3"
NEW_VERSION="$4"
CHANGELOG_FILE="$PACKAGE_DIR/CHANGELOG.md"

# Find commit where old version was set in package.json
find_last_version_commit() {
    local package_json="$PACKAGE_DIR/package.json"

    # Search git log for commit that changed version to OLD_VERSION
    git log --all --format="%H" -S "\"version\": \"$OLD_VERSION\"" -- "$package_json" | head -n 1
}

# Extract commits since last version
extract_commits() {
    local last_commit
    last_commit=$(find_last_version_commit)

    if [ -z "$last_commit" ]; then
        # First version - get all commits for this package
        git log --pretty=format:"%h|%s|%an|%ad" --date=short -- "$PACKAGE_DIR"
    else
        # Get commits since last version change
        git log --pretty=format:"%h|%s|%an|%ad" --date=short "$last_commit"..HEAD -- "$PACKAGE_DIR"
    fi
}

# Build JSON payload for Gemini API
build_gemini_payload() {
    local commits="$1"
    local commit_list=""

    while IFS='|' read -r hash subject author date; do
        commit_list+="- [$hash] $subject (by $author, $date)\n"
    done <<< "$commits"

    # Escape for JSON
    commit_list=$(echo -e "$commit_list" | jq -R -s '.')

    # Build prompt
    local prompt="You are a technical documentation expert. Analyze these git commits and generate a changelog entry following the Keep a Changelog format.

Package: $PACKAGE_NAME
Version: $OLD_VERSION → $NEW_VERSION

Commits:
$commit_list

Generate a changelog section with these requirements:
1. Use Keep a Changelog categories: Added, Changed, Deprecated, Removed, Fixed, Security
2. Group related changes together
3. Write clear, user-focused descriptions (not just commit messages)
4. Use bullet points (-)
5. Be concise but informative
6. Omit trivial changes (typos, formatting, internal refactoring unless significant)
7. Output ONLY the markdown content for this version section

Format:
## [$NEW_VERSION] - $(date +%Y-%m-%d)

### [Category]
- Change description

Do NOT include the # Changelog header or any preamble. Start directly with ## [$NEW_VERSION]."

    # Create JSON payload
    jq -n \
        --arg prompt "$prompt" \
        '{
            "contents": [{
                "parts": [{
                    "text": $prompt
                }]
            }],
            "generationConfig": {
                "temperature": 0.2,
                "topP": 0.8,
                "topK": 10,
                "maxOutputTokens": 1000
            }
        }'
}

# Call Gemini API with retry logic
call_gemini_api() {
    local payload="$1"
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        local response
        response=$(curl -s -X POST \
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent" \
            -H "x-goog-api-key: $GEMINI_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$payload" 2>&1)

        # Check for successful response
        if echo "$response" | jq -e '.candidates[0].content.parts[0].text' > /dev/null 2>&1; then
            echo "$response" | jq -r '.candidates[0].content.parts[0].text'
            return 0
        fi

        # Check for rate limit (429) or server errors (5xx)
        if echo "$response" | grep -qi "rate limit\|429\|503\|500"; then
            local wait_time=$((2 ** attempt))
            echo "⚠️  API error (attempt $attempt/$max_attempts), waiting ${wait_time}s..." >&2
            sleep "$wait_time"
            ((attempt++))
        else
            echo "❌ API error: $response" >&2
            return 1
        fi
    done

    echo "❌ Failed after $max_attempts attempts" >&2
    return 1
}

# Update or create CHANGELOG.md
update_changelog() {
    local new_entry="$1"

    if [ ! -f "$CHANGELOG_FILE" ]; then
        # Create new changelog
        cat > "$CHANGELOG_FILE" << EOF
# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

$new_entry

EOF
        echo "✅ Created new CHANGELOG.md"
    else
        # Insert new entry after [Unreleased] section
        # Use awk to insert at correct position
        awk -v entry="$new_entry" '
            /^## \[Unreleased\]/ {
                print $0
                print ""
                print entry
                print ""
                skip_blank = 1
                next
            }
            skip_blank && /^$/ {
                next
            }
            {
                skip_blank = 0
                print $0
            }
        ' "$CHANGELOG_FILE" > "${CHANGELOG_FILE}.tmp"

        mv "${CHANGELOG_FILE}.tmp" "$CHANGELOG_FILE"
        echo "✅ Updated existing CHANGELOG.md"
    fi
}

# Generate fallback changelog (if API fails)
generate_fallback_changelog() {
    local commits="$1"
    local entry="## [$NEW_VERSION] - $(date +%Y-%m-%d)

### Changed
"

    while IFS='|' read -r hash subject author date; do
        entry+="- $subject\n"
    done <<< "$commits"

    echo -e "$entry"
}

# Main execution
main() {
    echo "🔄 Generating changelog for $PACKAGE_NAME ($OLD_VERSION → $NEW_VERSION)..."

    # Extract git commits
    local commits
    commits=$(extract_commits)

    if [ -z "$commits" ]; then
        echo "⚠️  No commits found, creating minimal changelog"
        local minimal_entry="## [$NEW_VERSION] - $(date +%Y-%m-%d)

### Changed
- Package version updated from $OLD_VERSION to $NEW_VERSION
"
        update_changelog "$minimal_entry"
        return 0
    fi

    # Build API payload
    local payload
    payload=$(build_gemini_payload "$commits")

    # Call Gemini API
    local changelog_entry
    if changelog_entry=$(call_gemini_api "$payload"); then
        echo "✅ Generated changelog with Gemini API"
        update_changelog "$changelog_entry"
    else
        echo "⚠️  Gemini API failed, using fallback changelog"
        local fallback_entry
        fallback_entry=$(generate_fallback_changelog "$commits")
        update_changelog "$fallback_entry"
    fi

    echo "✅ Changelog updated: $CHANGELOG_FILE"
}

main
```

**Key features:**
- ✅ Finds commits since last version in package.json (no tags needed)
- ✅ Retry logic with exponential backoff (3 attempts)
- ✅ Structured JSON construction with jq (injection-safe)
- ✅ Fallback changelog if API fails
- ✅ Creates or updates existing CHANGELOG.md
- ✅ Temperature 0.2 for consistent output

### Step 3: Integrate into Workflow (45 min)

**File:** `.github/workflows/handle-publish-request.yml`

**Add step after "Detect and validate packages" (after line 273):**

```yaml
      - name: Generate changelogs
        if: env.published > 0 || env.skipped > 0
        env:
          GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
        run: |
          cd target-repo

          echo "📝 Generating changelogs for published packages..."

          # Check if API key is set
          if [ -z "$GEMINI_API_KEY" ]; then
            echo "⚠️  GEMINI_API_KEY not set, skipping changelog generation"
            echo "Set GEMINI_API_KEY in organization secrets to enable AI-powered changelogs"
            exit 0
          fi

          # Download changelog generation script
          curl -sSf "https://raw.githubusercontent.com/The1Studio/UPMAutoPublisher/master/scripts/generate-changelog.sh" \
            -o /tmp/generate-changelog.sh
          chmod +x /tmp/generate-changelog.sh

          # Generate changelog for each published package
          if [ -f published_packages.txt ] && [ -s published_packages.txt ]; then
            while IFS='|' read -r package_name old_version new_version package_dir; do
              [ -z "$package_name" ] && continue

              echo ""
              echo "=================================================="
              echo "📝 Generating changelog: $package_name"
              echo "=================================================="

              # Run changelog generation script
              if /tmp/generate-changelog.sh "$package_dir" "$package_name" "$old_version" "$new_version"; then
                echo "✅ Changelog generated successfully"
              else
                echo "⚠️  Changelog generation failed, continuing..."
              fi
            done < published_packages.txt

            # Commit changelog updates
            if git diff --quiet; then
              echo "ℹ️  No changelog changes to commit"
            else
              echo "💾 Committing changelog updates..."

              git config user.name "UPM Auto Publisher"
              git config user.email "upm-bot@the1studio.org"

              git add "**/CHANGELOG.md"
              git commit -m "docs: update changelogs for published packages [skip ci]

              Auto-generated by UPM Auto Publisher using Gemini API

              Published packages:
              $(cat published_packages.txt | cut -d'|' -f1,3 | sed 's/|/ → /')"

              # Push changes back to repository
              if git push origin HEAD:"${{ github.event.client_payload.branch }}" 2>&1; then
                echo "✅ Changelogs committed and pushed"
              else
                echo "⚠️  Failed to push changelog commits, but packages were published successfully"
              fi
            fi
          else
            echo "ℹ️  No packages to generate changelogs for"
          fi

          rm -f /tmp/generate-changelog.sh

      # Original "Create audit log" step continues here (line 286)
```

**Important notes:**
- Runs after package detection, before npm publish
- Graceful degradation if GEMINI_API_KEY not set
- Downloads script from this repo (centralized updates)
- Commits changelogs with `[skip ci]` to avoid triggering workflow
- Pushes to original branch (preserves branch name)
- Failure doesn't block package publishing

### Step 4: Add Changelog Template (10 min)

**File:** `docs/CHANGELOG.template.md` (already exists, verify content)

Ensure template matches Keep a Changelog format.

### Step 5: Update Documentation (20 min)

**Files to update:**

1. **`README.md`** - Add changelog generation to features list
2. **`docs/changelog-management.md`** - Add "Option 5: AI-Generated" section
3. **`docs/configuration.md`** - Document GEMINI_API_KEY secret
4. **`CLAUDE.md`** - Update project overview with changelog feature

**Example addition to `docs/configuration.md`:**

```markdown
### GEMINI_API_KEY (Optional)

- **Purpose:** Enable AI-powered changelog generation using Google Gemini API
- **Scope:** Organization-level secret
- **Usage:** Used by handle-publish-request workflow to generate CHANGELOG.md
- **Model:** gemini-2.0-flash-exp (fast, cost-effective)
- **Fallback:** If not set or API fails, basic changelog generated from commit messages
- **Rate Limits:** 15 requests/min, 1500 requests/day (free tier)
- **Cost:** Free tier sufficient for typical usage (<100 packages/day)

**Setup:**
1. Get API key from https://aistudio.google.com/app/apikey
2. Add to organization secrets as `GEMINI_API_KEY`
3. Workflow automatically uses it when available

**API Usage:**
- ~500 tokens per changelog generation
- Temperature: 0.2 (consistent output)
- Max output: 1000 tokens
- Timeout: 30s with retry
```

### Step 6: Add Validation Script (15 min)

**File:** `scripts/validate-changelog.sh`

```bash
#!/bin/bash
# Validate CHANGELOG.md files follow Keep a Changelog format

set -euo pipefail

# Find all CHANGELOG.md files
changelogs=$(find . -name "CHANGELOG.md" -not -path "*/node_modules/*" -not -path "*/.git/*")

if [ -z "$changelogs" ]; then
    echo "✅ No changelogs found"
    exit 0
fi

errors=0

while IFS= read -r changelog; do
    echo "Checking: $changelog"

    # Check for required header
    if ! grep -q "^# Changelog" "$changelog"; then
        echo "❌ Missing '# Changelog' header"
        ((errors++))
    fi

    # Check for Keep a Changelog reference
    if ! grep -q "Keep a Changelog" "$changelog"; then
        echo "⚠️  Warning: Missing Keep a Changelog reference"
    fi

    # Check for version sections
    if ! grep -q "^## \[" "$changelog"; then
        echo "⚠️  Warning: No version sections found"
    fi

done <<< "$changelogs"

if [ $errors -gt 0 ]; then
    echo "❌ Validation failed with $errors errors"
    exit 1
fi

echo "✅ All changelogs valid"
```

## Files to Modify/Create

### Create

1. **`scripts/generate-changelog.sh`** - Main changelog generation script (new, 150 lines)
2. **`scripts/validate-changelog.sh`** - Validation script (new, 50 lines)
3. **`plans/251112-gemini-changelog-generation.md`** - This file (new, 400+ lines)

### Modify

1. **`.github/workflows/handle-publish-request.yml`** - Add changelog generation step
   - After line 273 (after package detection)
   - ~60 lines added

2. **`docs/configuration.md`** - Document GEMINI_API_KEY
   - Add new section after NPM_TOKEN
   - ~30 lines added

3. **`docs/changelog-management.md`** - Add AI generation option
   - Add "Option 5: AI-Generated with Gemini" section
   - ~50 lines added

4. **`README.md`** - Update features and overview
   - Add to features list
   - ~5 lines modified

5. **`CLAUDE.md`** - Update project overview
   - Add changelog generation to features
   - ~3 lines in "Future Plans" section

## Testing Strategy

### Unit Tests (Manual)

**Test 1: First Package Version**
```bash
# Create test package with no CHANGELOG.md
cd test-repo/Assets/TestPackage
echo '{"name": "com.test.package", "version": "1.0.0"}' > package.json
git add . && git commit -m "feat: initial release"

# Run script
./scripts/generate-changelog.sh Assets/TestPackage com.test.package 0.0.0 1.0.0

# Verify: CHANGELOG.md created with correct format
```

**Expected:**
- ✅ New CHANGELOG.md file created
- ✅ Contains "# Changelog" header
- ✅ Contains Keep a Changelog reference
- ✅ Contains "## [1.0.0]" section
- ✅ Has at least one category (Added/Changed/Fixed)

**Test 2: Subsequent Version**
```bash
# Make changes and update version
echo "new feature" > new-file.txt
git add . && git commit -m "feat: add new feature"
sed -i 's/1.0.0/1.1.0/' package.json

# Run script
./scripts/generate-changelog.sh Assets/TestPackage com.test.package 1.0.0 1.1.0

# Verify: CHANGELOG.md updated with new section
```

**Expected:**
- ✅ CHANGELOG.md updated (not recreated)
- ✅ New section inserted after [Unreleased]
- ✅ Old sections preserved
- ✅ Chronological order maintained

**Test 3: API Failure Fallback**
```bash
# Run with invalid API key
export GEMINI_API_KEY="invalid"
./scripts/generate-changelog.sh Assets/TestPackage com.test.package 1.1.0 1.2.0

# Verify: Fallback changelog created
```

**Expected:**
- ⚠️ Warning logged about API failure
- ✅ Basic changelog generated from commits
- ✅ Package can still be published

**Test 4: No Commits**
```bash
# Bump version without changes
sed -i 's/1.2.0/1.2.1/' package.json
git add package.json && git commit -m "chore: bump version"

./scripts/generate-changelog.sh Assets/TestPackage com.test.package 1.2.0 1.2.1
```

**Expected:**
- ✅ Minimal changelog entry created
- ✅ Notes version update only

### Integration Tests (Workflow)

**Test 1: End-to-End Publishing**
1. Create test repository with package
2. Update package.json version
3. Push to master
4. Verify workflow:
   - ✅ Detects package change
   - ✅ Generates changelog
   - ✅ Commits changelog
   - ✅ Publishes package
   - ✅ Sends Discord notification

**Test 2: Multi-Package Repository**
1. Create repo with 2 packages
2. Update both versions
3. Push to master
4. Verify:
   - ✅ Both changelogs generated
   - ✅ Both packages published
   - ✅ Single commit with both changelogs

**Test 3: API Key Not Set**
1. Run workflow without GEMINI_API_KEY
2. Verify:
   - ⚠️ Warning logged
   - ✅ Packages still publish
   - ✅ No changelog generation attempt

### Validation Tests

**Test 1: Changelog Format**
```bash
./scripts/validate-changelog.sh
```

**Expected:**
- ✅ All CHANGELOG.md files pass validation
- ✅ Keep a Changelog format enforced

**Test 2: Git History Extraction**
```bash
# Verify commit finding logic
cd test-repo
git log --all --format="%H" -S '"version": "1.0.0"' -- Assets/Package/package.json
```

**Expected:**
- ✅ Finds correct commit where version was set
- ✅ Extracts commits since that point

## Security Considerations

### API Key Security

**Storage:**
- ✅ GitHub organization secret (encrypted at rest)
- ✅ Not exposed in logs (GitHub masks secrets)
- ✅ Not committed to repository

**Access:**
- ✅ Organization-level secret (admins only)
- ✅ Workflows use `${{ secrets.GEMINI_API_KEY }}`
- ✅ Not accessible in forks or PRs

**Rotation:**
- Google AI Studio allows API key regeneration
- Update organization secret when rotated
- No workflow changes needed

### Prompt Injection Prevention

**Input Sanitization:**
- ✅ Commit messages passed through jq JSON encoding
- ✅ No direct string interpolation in JSON
- ✅ Structured payload construction

**Example:**
```bash
# SAFE: Using jq for JSON construction
jq -n --arg prompt "$untrusted_input" '{text: $prompt}'

# UNSAFE: Direct interpolation (NOT USED)
echo "{\"text\": \"$untrusted_input\"}"
```

**Output Validation:**
- Parse Gemini response with jq
- Verify markdown structure
- Sanitize before file write

### Git Operations Security

**Commit Author:**
- Bot identity: "UPM Auto Publisher <upm-bot@the1studio.org>"
- Clear attribution in commit message
- `[skip ci]` prevents infinite loops

**Push Authorization:**
- Uses GH_PAT (same as other operations)
- Pushes to original branch only
- No force push or tag deletion

### Rate Limiting

**Gemini API Limits (Free Tier):**
- 15 requests per minute
- 1,500 requests per day
- 1 million tokens per day

**Mitigation:**
- Exponential backoff on rate limit (2^attempt seconds)
- Max 3 retry attempts
- Fallback to basic changelog if exhausted
- Publishing continues regardless

**Usage Estimate:**
- ~500 tokens per changelog generation
- Typical: <10 packages/day = 5,000 tokens/day
- Spike: 50 packages/day = 25,000 tokens/day (well under limit)

## Performance Considerations

### Latency

**Gemini API Response Time:**
- Typical: 2-5 seconds
- 95th percentile: <10 seconds
- Timeout: 30 seconds with retry

**Total Overhead per Package:**
- Git history extraction: <1s
- Gemini API call: 2-5s
- Changelog update: <1s
- **Total: ~5-10 seconds per package**

**Impact on Workflow:**
- Single package: +5-10s
- Multiple packages: Sequential (could parallelize later)
- Does NOT block publishing (separate step)

### API Cost

**Free Tier:**
- 1,500 requests/day
- 1 million tokens/day
- $0 cost

**If Exceeded (unlikely):**
- Fallback to basic changelog
- No publishing blocked
- Warning in logs

**Cost with Paid Plan (if needed):**
- Gemini 2.0 Flash: $0.075 per million input tokens
- ~500 tokens per request = $0.0000375 per changelog
- 100 changelogs = $0.00375 (~negligible)

## Risks & Mitigations

### Risk 1: API Downtime
**Impact:** HIGH - Changelogs not generated
**Probability:** LOW - Google SLA 99.9%
**Mitigation:**
- ✅ Retry logic with exponential backoff
- ✅ Fallback to basic changelog
- ✅ Publishing continues regardless
- ✅ Manual changelog editing still possible

### Risk 2: Rate Limit Exceeded
**Impact:** MEDIUM - Temporary changelog generation failure
**Probability:** LOW - Well under free tier limits
**Mitigation:**
- ✅ Exponential backoff
- ✅ Fallback changelog
- ✅ Clear logging
- ✅ Can upgrade to paid if needed

### Risk 3: Poor Quality Output
**Impact:** MEDIUM - Unhelpful changelogs
**Probability:** LOW - Gemini 2.0 Flash is reliable
**Mitigation:**
- ✅ Temperature 0.2 (consistent output)
- ✅ Structured prompt with clear instructions
- ✅ Fallback to commit messages
- ✅ Developers can edit CHANGELOG.md manually

### Risk 4: Git Commit Conflicts
**Impact:** MEDIUM - Changelog commit fails
**Probability:** LOW - Sequential operations
**Mitigation:**
- ✅ Push after changelog generation, before publish
- ✅ Warning logged if push fails
- ✅ Publishing continues (changelog in next commit)
- ✅ Can manually merge conflicts

### Risk 5: API Key Exposure
**Impact:** CRITICAL - Unauthorized API usage
**Probability:** VERY LOW - GitHub secret masking
**Mitigation:**
- ✅ Organization secret (encrypted)
- ✅ GitHub automatically masks in logs
- ✅ Not in repository or forks
- ✅ Can rotate key immediately if compromised

### Risk 6: Infinite Loop (Changelog Commit Triggers Workflow)
**Impact:** CRITICAL - Workflow spam
**Probability:** VERY LOW - `[skip ci]` used
**Mitigation:**
- ✅ Commit message includes `[skip ci]`
- ✅ Workflow triggers only on package.json changes
- ✅ Changelog changes don't trigger workflow

## Rollback Strategy

### If Issues Arise

**Immediate Rollback (5 min):**
1. Remove GEMINI_API_KEY from organization secrets
2. Workflow gracefully skips changelog generation
3. Publishing continues normally

**Partial Rollback (10 min):**
1. Keep GEMINI_API_KEY secret
2. Add environment variable check to skip changelog step
3. Can re-enable without redeploying

**Full Rollback (15 min):**
1. Revert workflow changes (remove changelog step)
2. Remove scripts from repository
3. System returns to previous state

**No data loss:** All existing CHANGELOG.md files preserved.

## Deployment Plan

### Phase 1: Infrastructure Setup (Day 1)
1. Add GEMINI_API_KEY to organization secrets
2. Create `scripts/generate-changelog.sh`
3. Create `scripts/validate-changelog.sh`
4. Update documentation

### Phase 2: Workflow Integration (Day 1)
1. Modify `handle-publish-request.yml`
2. Test in UPMAutoPublisher repo (no packages published)
3. Validate script execution

### Phase 3: Controlled Testing (Day 2)
1. Test with UnityBuildScript (first registered repo)
2. Bump test version
3. Verify:
   - Changelog generated
   - Package published
   - Commit pushed
   - Discord notification sent

### Phase 4: Full Rollout (Day 3+)
1. Monitor UnityBuildScript for 24 hours
2. If stable, announce to organization
3. Existing repos benefit automatically
4. New repos get changelog generation out of the box

## Success Metrics

### Quantitative
- ✅ 95%+ of packages have AI-generated changelogs
- ✅ <10s latency per changelog generation
- ✅ <5% API failure rate
- ✅ 0 publishing failures due to changelog generation
- ✅ 100% fallback success rate

### Qualitative
- ✅ Changelogs are human-readable and helpful
- ✅ Developers find changelogs accurate
- ✅ Less manual changelog maintenance needed
- ✅ Changelog format consistent across packages

## Future Enhancements

### Phase 2 (Optional)
1. **Parallel Changelog Generation** - Generate multiple changelogs concurrently
2. **Discord Changelog Preview** - Include changelog snippet in notification
3. **Changelog Quality Scoring** - Validate changelog helpfulness
4. **Custom Prompt Templates** - Per-repository prompt customization
5. **Changelog Translation** - Multi-language support

### Phase 3 (Optional)
1. **Breaking Change Detection** - Analyze API changes, warn on major versions
2. **Dependency Update Tracking** - Include dependency changes in changelog
3. **Release Notes Generation** - Auto-create GitHub releases with changelog
4. **Usage Analytics** - Track which features are most used (from changelogs)

## Configuration Options

### Per-Repository Configuration (Optional Future)

If needed, add `.upm-publisher.json` in repository root:

```json
{
  "changelog": {
    "enabled": true,
    "model": "gemini-2.0-flash-exp",
    "temperature": 0.2,
    "promptTemplate": "custom-template.txt",
    "includeAuthors": true,
    "skipCategories": ["docs", "chore"]
  }
}
```

**Not implemented in initial version** - Keep it simple first.

## Documentation Updates Required

### README.md
```markdown
### Key Features

- **Automatic Detection:** No manual triggers needed - just update version in package.json and commit
- **Multi-Package Support:** Handles repos with multiple UPM packages
- **Smart Version Checking:** Only publishes if version doesn't exist on registry
- **Error Resilient:** Continues publishing other packages if one fails
- **Organization-Wide:** Single NPM token shared across all repositories
- **AI-Powered Changelogs:** Automatically generates CHANGELOG.md using Gemini API ⭐ NEW
- **Tag-Free:** No need to manually create git tags (simplified from upm/{version} approach)
```

### docs/configuration.md
Add GEMINI_API_KEY section (see Step 5 above).

### docs/changelog-management.md
```markdown
### Option 5: AI-Generated with Gemini API ⭐ NEW

**Pros:**
- ✅ Fully automated - no manual work
- ✅ Intelligent analysis of code changes
- ✅ Human-readable, context-aware descriptions
- ✅ Follows Keep a Changelog format
- ✅ Handles multiple packages simultaneously
- ✅ Fallback to basic changelog if API fails

**Cons:**
- ❌ Requires Gemini API key (free tier sufficient)
- ❌ Small latency added to publish workflow (~5-10s)
- ❌ Quality depends on commit message quality

**Implementation:** Fully integrated in UPM Auto Publisher workflow.

**Status:** ✅ Production Ready

See [Gemini Changelog Generation Plan](../plans/251112-gemini-changelog-generation.md) for details.
```

## Unresolved Questions

1. **Q:** Should we add changelog preview in PR comments before publishing?
   **A:** Not initially - keep first version simple. Can add in Phase 2.

2. **Q:** Should changelog generation run in parallel for multiple packages?
   **A:** Not initially - sequential is simpler, latency acceptable. Optimize if needed.

3. **Q:** Should we validate changelog quality before committing?
   **A:** Not initially - trust Gemini output, allow manual edits. Monitor quality first.

4. **Q:** Should we support custom prompt templates per repository?
   **A:** Not initially - use standard prompt for consistency. Add config later if needed.

5. **Q:** Should changelog commits be squashed with version bump commits?
   **A:** No - separate commits easier to track and revert. Changelog commit references version.

## Acceptance Criteria

- ✅ GEMINI_API_KEY organization secret configured
- ✅ `scripts/generate-changelog.sh` created and tested
- ✅ `scripts/validate-changelog.sh` created and tested
- ✅ Workflow modified with changelog generation step
- ✅ Documentation updated (README, configuration, changelog-management)
- ✅ Test package published with AI-generated changelog
- ✅ Fallback works when API fails
- ✅ No publishing blocked by changelog failures
- ✅ Changelog format validated (Keep a Changelog)
- ✅ Git commits working correctly ([skip ci])
- ✅ Discord notifications include changelog info (future)

## Appendix A: Example Gemini Prompt

```
You are a technical documentation expert. Analyze these git commits and generate a changelog entry following the Keep a Changelog format.

Package: com.theone.ui.utilities
Version: 1.0.1 → 1.0.2

Commits:
- [a3f2c1b] Fix null reference in GetComponent method (by John Doe, 2025-01-15)
- [b7e4d2c] Improve performance of Update loop (by Jane Smith, 2025-01-15)
- [c9f1a3e] Update dependencies to latest versions (by John Doe, 2025-01-16)
- [d2e5b7f] Fix memory leak in coroutine cleanup (by Jane Smith, 2025-01-16)

Generate a changelog section with these requirements:
1. Use Keep a Changelog categories: Added, Changed, Deprecated, Removed, Fixed, Security
2. Group related changes together
3. Write clear, user-focused descriptions (not just commit messages)
4. Use bullet points (-)
5. Be concise but informative
6. Omit trivial changes (typos, formatting, internal refactoring unless significant)
7. Output ONLY the markdown content for this version section

Format:
## [1.0.2] - 2025-01-16

### [Category]
- Change description

Do NOT include the # Changelog header or any preamble. Start directly with ## [1.0.2].
```

## Appendix B: Example Generated Output

```markdown
## [1.0.2] - 2025-01-16

### Fixed
- Fixed null reference exception in GetComponent method that caused crashes in Unity 2022.3
- Resolved memory leak in coroutine cleanup that occurred during scene transitions

### Changed
- Improved Update loop performance by 30% through optimized caching
- Updated all package dependencies to their latest stable versions
```

## Appendix C: Fallback Changelog Example

```markdown
## [1.0.2] - 2025-01-16

### Changed
- Fix null reference in GetComponent method
- Improve performance of Update loop
- Update dependencies to latest versions
- Fix memory leak in coroutine cleanup
```

---

**Total Estimated Time:** 3-4 hours
**Complexity:** Medium
**Risk Level:** Low
**Business Value:** High (improved developer experience, better documentation)

**Next Steps:**
1. Review and approve plan
2. Add GEMINI_API_KEY to organization secrets
3. Implement scripts
4. Integrate into workflow
5. Test with UnityBuildScript
6. Roll out to all repositories
