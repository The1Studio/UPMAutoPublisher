# CLAUDE.md - UPM Auto Publisher

This file provides guidance to Claude Code when working with this repository.

## Project Overview

**UPM Auto Publisher** is an automation system for The1Studio organization that automatically publishes Unity Package Manager (UPM) packages to `upm.the1studio.org` when package versions are updated.

**Purpose:** Simplify the package publishing workflow from 7 manual steps to just 2 (update version + push).

**Key Components:**
- GitHub Actions workflow template (`.github/workflows/publish-upm.yml`)
- Repository registry (`config/repositories.json`)
- Comprehensive documentation (`docs/`)

## Repository Structure

```
UPMAutoPublisher/
├── .github/workflows/
│   └── publish-upm.yml           # Main workflow template
├── config/
│   ├── repositories.json         # Registry of repos using auto-publishing
│   └── schema.json              # JSON schema for validation
├── docs/
│   ├── setup-instructions.md    # How to add workflow to repos
│   ├── npm-token-setup.md       # NPM authentication setup
│   ├── troubleshooting.md       # Common issues and solutions
│   └── architecture-decisions.md # Design rationale
├── README.md                     # Main documentation
└── CLAUDE.md                     # This file

```

## How It Works

### Workflow Trigger
```yaml
on:
  push:
    branches: [master, main]
    paths: ['**/package.json']
```

### Publishing Logic
1. Detect changed `package.json` files via `git diff`
2. Extract package name and version from each file
3. Check if version exists on `upm.the1studio.org`
4. If new version: publish to registry
5. **NEW:** Generate AI-powered changelogs for published packages
6. Commit and push CHANGELOG.md updates back to repository
7. Continue with other packages if one fails

### Key Design Decisions
- **Trigger:** On commit (not on tags)
- **Authentication:** Organization-level NPM token
- **Discovery:** Auto-detect packages (no config needed)
- **Error Handling:** Continue on failure (multi-package support)
- **Tags:** No automatic git tag creation
- **Registry Configuration:** Uses `--registry` flag with environment variables (NOT publishConfig in package.json)
- **AI Changelogs:** Optional automatic changelog generation using Gemini AI (requires GEMINI_API_KEY)

### Registry Configuration Approach

**IMPORTANT:** The workflow does NOT require `publishConfig` in `package.json`.

**How it works:**
```yaml
# In .github/workflows/publish-upm.yml:
env:
  UPM_REGISTRY: ${{ vars.UPM_REGISTRY || 'https://upm.the1studio.org/' }}

# Publishing command (line 377):
npm publish --registry "$UPM_REGISTRY"
```

**Why this approach:**
- ✅ Centralized registry configuration (change once, applies to all)
- ✅ No need to modify each package.json
- ✅ Supports organization-level registry variable
- ✅ Falls back to default if variable not set
- ✅ Cleaner package.json files

**What this means for package.json:**
- `publishConfig.registry` is **optional** (NOT required)
- Workflow always provides registry via `--registry` flag
- If present, publishConfig is ignored (workflow flag takes precedence)

### Auto-Merge Feature

**NEW:** PRs created in target repositories now have auto-merge enabled automatically.

**How it works:**
```yaml
# In register-repos.yml after PR creation:
gh pr merge "$pr_url" --auto --squash
```

**Behavior:**
- ✅ PR auto-merges when all checks pass
- ✅ Uses squash strategy for clean history
- ⚠️ May fail if branch protection requires reviews
- 📝 Graceful failure - PR remains open for manual merge if auto-merge fails

**Benefits:**
- Reduces manual overhead
- Faster deployment cycle
- PRs merge automatically when CI passes

**When manual merge is needed:**
- Repository has branch protection requiring reviews
- Repository requires status checks that haven't passed yet
- Auto-merge permission not available

### GH_PAT Requirement

**CRITICAL:** The system requires `GH_PAT` (Personal Access Token) organization secret.

**Why needed:**
- `GITHUB_TOKEN` cannot trigger other workflows (GitHub security feature to prevent infinite loops)
- `manual-register-repo.yml` commits to master and needs to trigger `register-repos` workflow
- `register-repos.yml` needs to create PRs in target repositories

**Setup:**
1. Create PAT at https://github.com/settings/tokens
2. Select scopes: `repo`, `workflow`
3. Set expiration: 90 days (recommended)
4. Add to organization secrets as `GH_PAT`

**Token Validation:**
Workflows automatically validate GH_PAT before processing:
```yaml
- name: Validate GH_PAT
  run: |
    if ! gh auth status 2>/dev/null; then
      echo "❌ GH_PAT is invalid or expired"
      exit 1
    fi
```

**Rotation:**
- Must rotate every 90 days (or at expiration)
- GitHub will email warnings before expiration
- Workflows fail with clear error if GH_PAT expires
- See `docs/configuration.md#gh_pat-setup` for rotation procedure

### AI Changelog Generation

**NEW FEATURE:** Automatic changelog generation using Google Gemini AI.

**Overview:**
After packages are published successfully, the workflow automatically generates changelog entries by analyzing git commit history and using AI to create user-facing descriptions.

**How it works:**
1. Workflow downloads `scripts/generate-changelog.sh` from UPMAutoPublisher
2. For each published package:
   - Extracts git commits since last version in package directory
   - Sends commit history to Gemini AI with structured prompt
   - AI generates changelog entry in "Keep a Changelog" format
   - Updates or creates CHANGELOG.md next to package.json
3. Commits all changelog changes with `[skip ci]` message
4. Pushes changes back to source repository using GH_PAT

**Requirements:**
- `GEMINI_API_KEY` organization secret (optional)
- `GH_PAT` secret with `repo` scope (already required for other features)

**Setup:**
```bash
# Get API key from https://aistudio.google.com/apikey
gh secret set GEMINI_API_KEY \
  --body "AIza_your_key_here" \
  --org The1Studio
```

**Behavior:**
- ✅ Only runs after successful publishes (`if: env.published > 0`)
- ✅ Uses `continue-on-error: true` to never fail workflow
- ✅ Graceful fallback if GEMINI_API_KEY not set or API fails
- ✅ Commits use `[skip ci]` to prevent infinite loops
- ✅ Free tier sufficient for typical usage (<100 packages/day)

**Generated format:**
```markdown
## [1.0.2] - 2025-01-16

### Fixed
- Fixed null reference exception in GetComponent method
- Resolved memory leak in coroutine cleanup

### Changed
- Improved Update loop performance by 30%
```

**Workflow integration:**
- Located in `.github/workflows/handle-publish-request.yml` (lines 286-396)
- Runs after package detection, before audit log creation
- Downloads script fresh on each run to ensure latest version
- Processes all published packages in single commit

**Manual usage:**
```bash
# Download script
curl -sSfL \
  "https://raw.githubusercontent.com/The1Studio/UPMAutoPublisher/master/scripts/generate-changelog.sh" \
  -o generate-changelog.sh
chmod +x generate-changelog.sh

# Run for specific package
./generate-changelog.sh \
  "path/to/package.json" \
  "old_version" \
  "new_version" \
  "your-gemini-api-key"
```

**See:** `docs/configuration.md#gemini_api_key-setup` for complete details

### AI Package.json Validation

**NEW FEATURE:** Real-time package.json validation using Google Gemini AI.

**Overview:**
Before publishing packages, the workflow automatically validates package.json files using AI to detect and fix issues, preventing failed publishes and maintaining quality standards.

**How it works:**
1. Validates package.json before npm publish
2. Checks for:
   - JSON syntax errors (missing/trailing commas)
   - Missing required UPM fields
   - Invalid formats (package name, semver, Unity version)
   - Dependency issues
3. If critical issues found:
   - Auto-fixes the issues if possible
   - Creates PR with fixes in target repository
   - Enables auto-merge on the fix PR
   - Skips publish until fix is merged
4. If only warnings found:
   - Logs warnings but continues with publish
5. Uses validation guide at `docs/package-json-validation-guide.md`

**Requirements:**
- `GEMINI_API_KEY` organization secret (optional but recommended)
- `GH_PAT` secret with `repo` scope (already required)

**Behavior:**
- ✅ Runs on every publish attempt (not just weekly)
- ✅ Auto-fixes critical issues and creates PRs
- ✅ Enables auto-merge on fix PRs
- ✅ Graceful fallback if API not available
- ✅ Uses temperature 0.1 for deterministic validation
- ✅ Never fails workflow - only skips problematic packages

**Example Flow:**
```
Package detected → Gemini validation
  ├─ ✅ Valid → Continue to publish
  ├─ ⚠️ Warnings → Log warnings + publish
  └─ ❌ Critical issues
      ├─ Auto-fix available → Create PR + skip publish
      └─ No auto-fix → Skip publish + log error
```

**Validation Guide:**
Complete validation rules documented at `docs/package-json-validation-guide.md`

**See:** `docs/configuration.md#gemini_api_key-setup` for setup details

## Common Tasks

### Adding a New Repository to the Registry

1. Edit `config/repositories.json`:
```json
{
  "name": "NewRepository",
  "url": "https://github.com/The1Studio/NewRepository",
  "status": "active",
  "packages": [
    {
      "name": "com.theone.newpackage",
      "path": "Assets/NewPackage",
      "latestVersion": "1.0.0"
    }
  ]
}
```

2. Validate JSON:
```bash
jq . config/repositories.json
```

### Updating Documentation

All documentation is in `docs/`:
- **Setup:** `setup-instructions.md`
- **NPM Token:** `npm-token-setup.md`
- **Troubleshooting:** `troubleshooting.md`
- **Architecture:** `architecture-decisions.md`

When updating docs:
- Keep examples current
- Update "lastUpdated" date in repository.json
- Cross-reference related docs
- Test commands/code samples

### Modifying the Workflow

Template is in `.github/workflows/publish-upm.yml`

**Important sections:**
- **Triggers:** Lines 3-9 (when workflow runs)
- **Node setup:** Lines 17-20 (Node.js version)
- **Detection:** Lines 35-39 (finding changed files)
- **Publishing:** Lines 92-100 (npm publish command)

**Testing changes:**
1. Create test repo or use existing
2. Copy modified workflow to test repo
3. Make package.json change and push
4. Verify workflow behavior in Actions tab
5. Check package published to registry

## Environment Setup

### Prerequisites
- Node.js 18+ (for testing locally)
- `jq` for JSON manipulation
- `gh` CLI (optional, for GitHub operations)
- Access to The1Studio organization
- NPM authentication to `upm.the1studio.org`

### Local Testing

Test workflow logic without running in GitHub Actions:

```bash
# Simulate change detection
changed_files=$(git diff --name-only HEAD~1 HEAD | grep 'package\.json$')

# Process each package
for package_json in $changed_files; do
  package_name=$(jq -r '.name' "$package_json")
  new_version=$(jq -r '.version' "$package_json")

  echo "Would publish: $package_name@$new_version"

  # Test if version exists
  npm view "$package_name@$new_version" --registry https://upm.the1studio.org/

  # Dry-run publish
  cd "$(dirname "$package_json")"
  npm publish --dry-run --registry https://upm.the1studio.org/
done
```

## NPM Token Management

### Current Token Location
- Stored as: `NPM_TOKEN` GitHub organization secret
- Scope: The1Studio organization
- Registry: `upm.the1studio.org`

### Checking Token
```bash
# Verify token works
npm whoami --registry https://upm.the1studio.org/
# Should output: admin

# List tokens
npm token list --registry https://upm.the1studio.org/
```

### Rotating Token
See `docs/npm-token-setup.md` for complete instructions.

## Troubleshooting Quick Reference

### Workflow Not Running
- Check branch is master/main
- Verify package.json actually changed
- Check Actions are enabled in repo settings

### Publish Failed
- Verify NPM_TOKEN secret exists
- ~~Check package.json has `publishConfig.registry`~~ **NOT REQUIRED** - Workflow uses `--registry` flag with environment variables
- Ensure version doesn't already exist

### Multi-Package Issues
- ~~Each must have `publishConfig.registry`~~ **NOT REQUIRED** - Registry configured via workflow environment variables
- Check workflow logs for each package
- Verify all packages have unique names

**Full troubleshooting:** See `docs/troubleshooting.md`

## Architecture Principles

1. **Developer Experience First:** Minimize steps to publish
2. **Fail Safe:** Can re-run workflows safely
3. **Organization-Wide:** Consistent across all repos
4. **Minimal Configuration:** Auto-discovery preferred
5. **Observable:** Clear logging and error messages

See `docs/architecture-decisions.md` for detailed rationale.

## Important Files

### Workflow Template
**Location:** `.github/workflows/publish-upm.yml`
**Purpose:** Copy this to repositories that need auto-publishing
**Critical:** Keep Node.js version updated, validate YAML syntax

### Repository Registry
**Location:** `config/repositories.json`
**Purpose:** Track which repos use auto-publishing
**Maintenance:** Update when repos added/removed

### Documentation
**Location:** `docs/*.md`
**Purpose:** Comprehensive guides for setup and troubleshooting
**Maintenance:** Keep examples current, test commands

## Development Workflow

### Making Changes

1. **Create Branch:**
   ```bash
   git checkout -b feature/your-change
   ```

2. **Make Changes:**
   - Update relevant files
   - Test locally if possible
   - Update documentation if needed

3. **Validate:**
   ```bash
   # Validate JSON files
   jq . config/repositories.json

   # Validate YAML
   yamllint .github/workflows/publish-upm.yml
   ```

4. **Commit:**
   ```bash
   git add .
   git commit -m "Description of change"
   ```

5. **Push & PR:**
   ```bash
   git push origin feature/your-change
   # Create PR on GitHub
   ```

### Testing in Real Repository

To test workflow changes:

1. Choose a test repository with UPM package
2. Copy modified workflow to test repo
3. Create test version bump
4. Push and monitor Actions tab
5. Verify package published correctly
6. Check logs for errors/warnings

## Security Considerations

### NPM Token
- Stored as organization secret
- Has write permissions to registry
- Should be rotated annually
- If compromised: revoke immediately

### Workflow Permissions
- Uses `secrets.NPM_TOKEN`
- No write access to repository needed (no tag creation)
- Minimal permissions principle

### Package Validation
- ~~Only publishes if `publishConfig.registry` matches~~ **Registry specified via `--registry` flag in workflow**
- Checks version doesn't exist first
- Validates package.json structure

## Communication

### When to Update Registry
Update `config/repositories.json` when:
- New repository adds auto-publishing
- Repository removes auto-publishing
- Package added/removed from repo
- Major version milestone reached

### Documentation Updates
Update docs when:
- Workflow behavior changes
- New troubleshooting scenario discovered
- Security requirements change
- New best practice identified

## Validation & Testing 🆕

### Pre-Deployment Validation
Before deploying or after making changes:
```bash
./scripts/pre-deployment-check.sh
```
Validates 37+ checks covering file structure, configuration, security, and dependencies.

### Configuration Validation
```bash
./scripts/validate-config.sh  # Validate repositories.json against schema
```

### Repository Auditing
```bash
./scripts/audit-repos.sh  # Check all registered repos and workflow status
```

### Single Repository Check
```bash
./scripts/check-single-repo.sh UnityBuildScript
```

## References

### Getting Started
- **Main Docs:** `README.md`
- **Quick Registration:** `docs/quick-registration.md` 🆕 **Automated repo setup (2 min)**
- **Setup Guide:** `docs/setup-instructions.md` (Manual process)
- **Token Setup:** `docs/npm-token-setup.md`

### Configuration & Operations
- **Configuration Guide:** `docs/configuration.md` 🆕 **All configurable options, org variables, audit logs**
- **Self-Hosted Runners:** `docs/self-hosted-runners.md`
- **Docker Setup:** `.docker/README.md`
- **Troubleshooting:** `docs/troubleshooting.md`

### Security & Compliance 🆕
- **Security Improvements:** `docs/security-improvements.md` - **Complete security audit (25 issues, 18 fixed)**
- **Pre-Deployment Check:** `scripts/pre-deployment-check.sh` - **Automated validation (37+ checks)**

### Architecture & Design
- **Architecture:** `docs/architecture-decisions.md`
- **Registration System:** `docs/registration-system-overview.md`

## Project Context

### Origin
Created 2025-01-16 to automate UPM package publishing for The1Studio organization.

### Current Status
- **Version 1.1.0** (2025-10-13)
- **Security Score: A-** (Production Ready)
- Active development with security hardening complete
- UnityBuildScript is first registered repository

### Recent Improvements (v1.1.0)
- ✅ Fixed 18 critical/high/major security issues
- ✅ Added configurable registry URL
- ✅ Added comprehensive audit logging (90-day retention)
- ✅ Added version rollback prevention
- ✅ Added registry health checks
- ✅ Added pre-deployment validation script
- ✅ Created comprehensive security documentation

### Future Plans (Optional Enhancements)
- Roll out to all The1Studio UPM packages
- Add notifications (Slack/Discord) - template in docs
- Implement changelog generation
- Add metrics and analytics

## For Future Claude Sessions

When starting a new session on this project:

1. **Read README.md first** - Understand overall system
2. **Check config/repositories.json** - See current registered repos
3. **Review recent commits** - Understand recent changes
4. **Check open issues** - Known problems or planned work
5. **Read architecture-decisions.md** - Understand why things work this way

### Common Session Types

**Adding new repository:**
- Edit config/repositories.json
- Verify package.json has correct registry
- Copy workflow to new repo
- Test with version bump

**Troubleshooting workflow:**
- Check docs/troubleshooting.md first
- Review GitHub Actions logs
- Test locally with commands from this file
- Update troubleshooting doc if new issue

**Updating documentation:**
- Locate relevant doc in docs/
- Update content
- Test code examples
- Update cross-references
- Update lastUpdated dates

## Version History

- **v1.1.0** (2025-10-13): Security hardening & quality improvements
  - ✅ Fixed all 18 critical/high/major security issues
  - ✅ Added configurable registry URL (organization variables)
  - ✅ Added comprehensive audit logging (90-day retention)
  - ✅ Added version rollback prevention
  - ✅ Added registry health checks
  - ✅ Added package size warnings
  - ✅ Added pre-deployment validation script (37+ checks)
  - ✅ Created comprehensive security documentation
  - 🎯 Security score: C → A- (Production Ready)

- **v1.0.0** (2025-01-16): Initial release
  - GitHub Actions workflow
  - Auto-detection and publishing
  - Multi-package support
  - Comprehensive documentation

---

**Remember:** This system is designed to be simple, safe, and automatic. Keep that philosophy when making changes.

**Security Note:** All critical security issues have been resolved. System is production-ready with comprehensive validation tools and documentation.
