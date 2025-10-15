# UPM Auto Publisher

Automated Unity Package Manager (UPM) publishing system for The1Studio organization. This system automatically detects package version changes and publishes them to `upm.the1studio.org` registry.

---

## 📢 Want to Add Auto-Publishing to Your Repository?

**👉 [Click here for the 2-minute setup guide](#-quick-start---adding-new-repositories)**

It's easy! Just add your repository to `config/repositories.json`, commit, and let automation do the rest. No manual workflow setup required.

**Already set up?** Just update your `package.json` version and push - publishing happens automatically! 🚀

---

## Overview

This repository contains the GitHub Actions workflow and documentation for automatically publishing Unity packages to The1Studio's private UPM registry whenever package.json versions are updated.

### How It Works

1. **Trigger**: Monitors all registered repositories for commits to master/main branch
2. **Detection**: Identifies changed `package.json` files in the commit
3. **Version Check**: For each changed package:
   - Extracts package name and version from package.json
   - Queries `upm.the1studio.org` to check if version already exists
   - Skips if version is already published
4. **Publishing**: If new version detected:
   - Changes to package directory
   - Runs `npm publish --registry https://upm.the1studio.org/`
   - Handles errors gracefully (continues with other packages if one fails)
5. **Multi-Package Support**: Handles repos with multiple Unity packages

### Key Features

- **Automatic Detection**: No manual triggers needed - just update version in package.json and commit
- **Multi-Package Support**: Handles repos with multiple UPM packages
- **Smart Version Checking**: Only publishes if version doesn't exist on registry
- **Error Resilient**: Continues publishing other packages if one fails
- **Organization-Wide**: Single NPM token shared across all repositories
- **Tag-Free**: No need to manually create git tags (simplified from upm/{version} approach)

## Architecture

### Components

1. **GitHub Actions Workflow** (`.github/workflows/publish-upm.yml`)
   - Triggered on push to master/main
   - Detects package.json changes
   - Publishes to UPM registry

2. **Repository Registry** (`config/repositories.json`)
   - Lists all repositories that should use auto-publishing
   - Tracks package locations within each repo

3. **Setup Scripts** (`docs/setup-instructions.md`)
   - Step-by-step guide for adding workflow to new repos
   - NPM token configuration
   - GitHub organization secret setup

## 🚀 Quick Start - Adding New Repositories

### ⚡ For Normal Users: Register Your Repository (2 Minutes)

**Want to add UPM auto-publishing to your repository?** Follow these simple steps:

#### Step 1: Add Your Repository to the Registry (30 seconds)

Edit `config/repositories.json` in this repository and add your repo:

```json
{
  "name": "YourRepo",
  "url": "https://github.com/The1Studio/YourRepo",
  "status": "pending",
  "packages": [
    {
      "name": "com.theone.yourpackage",
      "path": "Assets/YourPackage"
    }
  ]
}
```

**Important:** Set `status: "pending"` to trigger automation.

#### Step 2: Commit and Push (10 seconds)

```bash
git add config/repositories.json
git commit -m "Register YourRepo for UPM auto-publishing"
git push origin master
```

#### Step 3: Wait for Automation (1-2 minutes)

The system automatically:
- ✅ Creates a pull request in your repository
- ✅ Adds the publishing workflow file
- ✅ Includes setup documentation

#### Step 4: Merge the PR (30 seconds)

Go to your repository and merge the automated PR titled "🤖 Add UPM Auto-Publishing Workflow"

#### Step 5: Update Status (20 seconds)

Change `"status": "pending"` to `"status": "active"` in `repositories.json` and commit.

#### Step 6: Test It! (1 minute)

Update your `package.json` version and push:
```bash
# Bump version in your package.json
sed -i 's/"version": "1.0.0"/"version": "1.0.1"/' Assets/YourPackage/package.json

git add Assets/YourPackage/package.json
git commit -m "Bump version to 1.0.1"
git push origin master
```

**Done!** 🎉 Your package will be automatically published to https://upm.the1studio.org/

**📖 Detailed Guide:** See [Quick Registration Guide](docs/quick-registration.md) for complete instructions, troubleshooting, and advanced options.

### For Repository Maintainers

To publish a new package version:

1. Update version in your package.json:
   ```json
   {
     "version": "1.2.11"  // Increment from 1.2.10
   }
   ```

2. Commit and push to master:
   ```bash
   git add Assets/YourPackage/package.json
   git commit -m "Bump version to 1.2.11"
   git push origin master
   ```

3. GitHub Actions automatically publishes to upm.the1studio.org

That's it! No tags, no manual publishing.

### For New Repository Setup

See [Setup Instructions](docs/setup-instructions.md) for adding the workflow to a new repository.

## Configuration

### Repository Registry

Track which repositories use auto-publishing in `config/repositories.json`:

```json
{
  "repositories": [
    {
      "name": "UnityBuildScript",
      "url": "https://github.com/The1Studio/UnityBuildScript",
      "status": "active",
      "packages": [
        {
          "name": "com.theone.foundation.buildscript",
          "path": "Assets/BuildScripts"
        }
      ]
    },
    {
      "name": "UnityUtilities",
      "url": "https://github.com/The1Studio/UnityUtilities",
      "status": "active",
      "packages": [
        {
          "name": "com.theone.utilities.core",
          "path": "Assets/Utilities/Core"
        },
        {
          "name": "com.theone.utilities.ui",
          "path": "Assets/Utilities/UI"
        }
      ]
    }
  ]
}
```

**Required Fields:**
- `name` - Repository name
- `url` - Full GitHub repository URL
- `status` - `"pending"` (triggers deployment), `"active"` (deployed), or `"disabled"` (skip)
- `packages[]` - Array of packages with `name` and `path`

### GitHub Secrets Required

- `NPM_TOKEN`: Organization-level secret for npm authentication
  - Used to publish to upm.the1studio.org
  - Set once at organization level, available to all repos

## Tag Naming Convention

For multi-package repositories, we use:
```
upm/{package-name}/{version}
```

Examples:
- `upm/buildscript/1.2.10`
- `upm/utilities-core/2.0.1`
- `upm/utilities-ui/1.5.3`

**Note**: Based on discussion, we're actually NOT creating tags automatically anymore to simplify the workflow. This section is kept for reference.

## Workflow Logic

```bash
# 1. Detect changed package.json files
changed_packages=$(git diff HEAD~1 --name-only | grep package.json)

# 2. For each changed package
for package_json in $changed_packages; do
  # Extract package info
  package_dir=$(dirname "$package_json")
  package_name=$(jq -r '.name' "$package_json")
  new_version=$(jq -r '.version' "$package_json")

  # Check if version exists on registry
  if ! npm view "$package_name@$new_version" --registry https://upm.the1studio.org/ 2>/dev/null; then
    echo "Publishing $package_name@$new_version..."

    # Publish to registry
    cd "$package_dir"
    npm publish --registry https://upm.the1studio.org/

    echo "✅ Published $package_name@$new_version"
  else
    echo "⏭️  Version $new_version already exists for $package_name, skipping"
  fi
done
```

## Error Handling

- **Version Already Exists**: Skip publishing, log message
- **Package Not Found**: Skip (not a UPM package)
- **Publish Fails**: Log error, continue with other packages
- **Auth Fails**: Stop workflow, report error

## Benefits

### Before (Manual Process)
1. Update package.json version
2. Commit changes
3. Create git tag: `git tag upm/1.2.10`
4. Push commit: `git push`
5. Push tag: `git push --tags`
6. CD to package directory
7. Publish: `npm publish --registry https://upm.the1studio.org/`

### After (Automated)
1. Update package.json version
2. Commit and push

**Time saved**: ~5 manual steps eliminated per release

## Troubleshooting

See [Troubleshooting Guide](docs/troubleshooting.md) for common issues and solutions.

## Requirements

### GitHub Repository
- Repository in The1Studio organization
- Unity package with package.json containing:
  - `name`: Package identifier
  - `version`: Semantic version
  - `publishConfig.registry`: Set to `https://upm.the1studio.org/`

### Self-Hosted Runners (ARC)

**⚠️ IMPORTANT**: This project uses **Actions Runner Controller (ARC)** self-hosted runners.

**Current Configuration:**
- **Platform**: Kubernetes with ARC
- **Namespace**: `arc-runners`
- **Runner Set**: `the1studio-org-runners`
- **Required Labels**: `[self-hosted, arc, the1studio, org]`
- **Active Runners**: 2+ runners must be available

**Benefits:**
- ✅ Unlimited GitHub Actions minutes
- ✅ Faster execution with local network and caching
- ✅ Running on dedicated 128GB RAM Kubernetes cluster
- ✅ Cost savings (no per-minute charges)

**Verify Runners:**
```bash
# Check runner status
kubectl get runner -n arc-runners

# View runner details
kubectl get pods -n arc-runners
```

**Expected Output:**
```
NAME                                   STATUS    ORGANIZATION
the1studio-org-runners-7kfln-b9z2r    Running   the1studio
the1studio-org-runners-7kfln-k7rr5    Running   the1studio
```

**Troubleshooting:**
- If workflows queue indefinitely: Check runner availability
- See [Self-Hosted Runners Guide](docs/self-hosted-runners.md) for setup and management
- To use GitHub-hosted runners: Change `runs-on` to `ubuntu-latest` in workflow files

## Related Documentation

### Getting Started
- [Quick Registration Guide](docs/quick-registration.md) - 🆕 **Automated repo registration (2 minutes)**
- [Setup Instructions](docs/setup-instructions.md) - Manual workflow setup
- [NPM Token Setup](docs/npm-token-setup.md) - Creating and configuring NPM authentication

### Configuration & Operations
- [Configuration Guide](docs/configuration.md) - 🆕 **All configurable options, organization variables, audit logs**
- [Self-Hosted Runners](docs/self-hosted-runners.md) - Docker-based custom runners
- [Troubleshooting Guide](docs/troubleshooting.md) - Common issues and solutions

### Security & Compliance
- [Security Improvements](docs/security-improvements.md) - 🆕 **Complete security audit & fixes (25 issues)**
- [Pre-Deployment Check](scripts/pre-deployment-check.sh) - 🆕 **Automated validation script (37+ checks)**

### Architecture & Design
- [Architecture Decisions](docs/architecture-decisions.md) - Design choices and rationale
- [Registration System Overview](docs/registration-system-overview.md) - How automated registration works

## Support

For issues or questions:
1. Check [Troubleshooting Guide](docs/troubleshooting.md)
2. Review [GitHub Actions logs](https://github.com/The1Studio/UPMAutoPublisher/actions)
3. Contact DevOps team

## Validation & Testing

### Pre-Deployment Validation

Before deploying to production or after making changes, run the comprehensive validation script:

```bash
./scripts/pre-deployment-check.sh
```

This validates:
- ✅ File structure completeness (12 critical files)
- ✅ JSON configuration syntax and schema
- ✅ Bash script syntax and security best practices
- ✅ GitHub Actions workflow security fixes
- ✅ Docker configuration security (secrets, no socket mounting)
- ✅ Security checks (no hardcoded credentials, safe parsing)
- ✅ All required dependencies installed

**Result:** Pass/Fail/Warning status with actionable recommendations

### Configuration Validation

Validate `config/repositories.json` against schema:

```bash
./scripts/validate-config.sh
```

### Repository Auditing

Check all registered repositories and verify their workflow status:

```bash
./scripts/audit-repos.sh
```

Provides comprehensive report on:
- Repository accessibility
- Workflow file existence and state
- Last workflow run status
- Status mismatches (registry vs actual)

### Single Repository Check

Quick status check for a specific repository:

```bash
./scripts/check-single-repo.sh UnityBuildScript
# or
./scripts/check-single-repo.sh The1Studio/UnityBuildScript
# or
./scripts/check-single-repo.sh https://github.com/The1Studio/UnityBuildScript
```

## Version History

- **v1.2.0** (2025-10-14): Critical security fixes from fresh code review
  - ✅ Fixed 3 HIGH priority issues (command injection, markdown injection, race conditions)
  - ✅ Fixed 5 MAJOR priority issues (rate limiting, token exposure, temp file security)
  - ✅ Fixed 2 MEDIUM/LOW issues (Docker versioning, Dependabot config)
  - 🔒 Command injection prevention with complete jq JSON construction
  - 🔒 Comprehensive markdown injection validation (links, HTML, code blocks)
  - 🔒 GitHub concurrency control replaces file-based locking
  - 🔒 npm rate limit handling with exponential backoff (5 attempts)
  - 🔒 Secure token validation without process list exposure
  - 🔒 Temp files with explicit 600 permissions
  - 🔒 Early GITHUB_WORKSPACE validation
  - 📦 Docker image version pinning (2.311.0)
  - 🤖 Dependabot configuration for automated updates
  - 🎯 Security score: A- → A (Hardened Production)
  - 📊 Total fixes: 10 additional security issues resolved

- **v1.1.0** (2025-10-14): Initial security hardening
  - ✅ Fixed 26 security issues from first audit
  - ✅ Added configurable registry URL, audit retention, package size threshold
  - ✅ Added comprehensive audit logging
  - ✅ Added version rollback prevention with semver
  - ✅ Added retry logic, Node.js verification, Docker resource limits
  - 🎯 Security score: C → A- (Production Ready)

- **v1.0.0** (2025-01-16): Initial release
  - Auto-detection of package.json changes
  - Organization-level NPM token
  - Multi-package repository support
  - No git tag requirement

## License

MIT License - See LICENSE file for details
