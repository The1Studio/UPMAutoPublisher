# UPM Auto Publisher - Scripts

Utility scripts for managing and auditing UPM auto-publishing setup.

## Available Scripts

### 1. `audit-repos.sh` - Comprehensive Audit ⭐ **Recommended**

**Purpose**: Complete audit of all registered repositories with detailed status and recommendations.

**Usage:**
```bash
./scripts/audit-repos.sh
```

**Features:**
- ✅ Checks all repos in `config/repositories.json`
- ✅ Verifies workflow file exists
- ✅ Checks workflow state (active/disabled)
- ✅ Shows run statistics and last run status
- ✅ Compares registry status vs actual state
- ✅ Provides recommendations for mismatches
- ✅ Color-coded output
- ✅ Summary statistics

**Output Example:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 UPM Auto Publisher - Repository Audit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Repository: UnityBuildScript
  URL: https://github.com/The1Studio/UnityBuildScript
  Registry Status: active
  Packages: 1
  ✅ Repository accessible
  ✅ Workflow file exists
      State: active
      Total runs: 15
      Last run: ✅ success (2025-01-15)

  Status Analysis:
  ✅ MATCHED - Registry 'active' and workflow exists

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Audit Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total Repositories: 1
Active:   1
Pending:  0
Disabled: 0

Verification:
  ✅ Matched:    1
  ❌ Mismatched: 0
```

**When to use:**
- 🔄 Regular audits (weekly/monthly)
- 🐛 Troubleshooting setup issues
- 📊 Before/after adding repos
- ✅ Verifying automated deployment

---

### 2. `quick-check.sh` - Fast Status Overview

**Purpose**: Quick table view of all repositories and their status.

**Usage:**
```bash
./scripts/quick-check.sh
```

**Features:**
- ⚡ Fast execution
- 📊 Table format
- ✅ Simple status indicators
- 🎨 Color-coded

**Output Example:**
```
🔍 Quick Status Check
====================

REPOSITORY                     REGISTRY STATUS  WORKFLOW
────────────────────────────── ─────────────── ───────────────
UnityBuildScript               active          ✅ EXISTS
UnityUtilities                 pending         ❌ MISSING
TheOneFeature                  active          ✅ EXISTS

💡 Tip: Run './scripts/audit-repos.sh' for detailed analysis
```

**When to use:**
- 🚀 Quick daily check
- 👀 Before meetings/reports
- 📋 Checking multiple repos fast

---

### 3. `check-single-repo.sh` - Single Repository Check

**Purpose**: Detailed check of one specific repository.

**Usage:**
```bash
./scripts/check-single-repo.sh <repository-name>

# Example:
./scripts/check-single-repo.sh UnityBuildScript
```

**Features:**
- 🎯 Focused on single repo
- 📝 Detailed workflow information
- 📊 Run statistics
- 🔗 Direct GitHub links

**Output Example:**
```
🔍 Checking: UnityBuildScript
====================

✅ Workflow file exists

Workflow Details:
  Name: Publish to UPM Registry
  State: active
  Path: .github/workflows/publish-upm.yml

Usage:
  Total runs: 15
  Last run: success (2025-01-15)

🔗 View in GitHub:
  https://github.com/The1Studio/UnityBuildScript/actions/workflows/publish-upm.yml
```

**When to use:**
- 🔍 Investigating specific repo
- 🐛 Debugging workflow issues
- ✅ Verifying single repo setup

---

## Prerequisites

All scripts require:
- ✅ **GitHub CLI (gh)**: https://cli.github.com/
- ✅ **jq**: JSON processor
- ✅ **Authenticated with GitHub**: `gh auth login`

**Install dependencies:**
```bash
# Arch Linux
sudo pacman -S github-cli jq

# Ubuntu/Debian
sudo apt-get install gh jq

# macOS
brew install gh jq

# Authenticate
gh auth login
```

## Installation

Make scripts executable:
```bash
chmod +x scripts/*.sh
```

## Usage Workflow

### Daily/Weekly Check
```bash
# Quick overview
./scripts/quick-check.sh

# If any issues, run full audit
./scripts/audit-repos.sh
```

### After Adding New Repository
```bash
# 1. Add repo to config/repositories.json with status: "pending"
# 2. Commit and push
# 3. Wait for automation to create PR
# 4. Merge PR in target repo

# 5. Run audit to verify
./scripts/audit-repos.sh

# 6. Update status to "active" if needed
# 7. Run audit again to confirm
./scripts/audit-repos.sh
```

### Troubleshooting Specific Repo
```bash
# Check single repo
./scripts/check-single-repo.sh RepoName

# If workflow missing, check registry
grep "RepoName" config/repositories.json

# Run full audit for recommendations
./scripts/audit-repos.sh
```

## Exit Codes

| Script | Exit 0 (Success) | Exit 1 (Error) |
|--------|-----------------|----------------|
| `audit-repos.sh` | All repos matched | Mismatches found |
| `quick-check.sh` | Always exits 0 | Prerequisites missing |
| `check-single-repo.sh` | Always exits 0 | Prerequisites missing |

**Using in CI/CD:**
```bash
# Fail CI if audit finds issues
./scripts/audit-repos.sh || exit 1
```

## Output Colors

Scripts use colors for readability:
- 🟢 **Green**: Success, active, exists
- 🔴 **Red**: Error, missing, failed
- 🟡 **Yellow**: Warning, pending, caution
- 🔵 **Blue**: Info, labels

## Script Comparison

| Feature | audit-repos.sh | quick-check.sh | check-single-repo.sh |
|---------|---------------|----------------|---------------------|
| **Speed** | Slow (detailed) | Fast | Medium |
| **Output** | Comprehensive | Table | Detailed single |
| **Recommendations** | ✅ Yes | ❌ No | ❌ No |
| **Run statistics** | ✅ Yes | ❌ No | ✅ Yes |
| **Mismatch detection** | ✅ Yes | ❌ No | ❌ No |
| **Summary** | ✅ Yes | ❌ No | ❌ No |
| **Best for** | Regular audits | Quick checks | Single repo debug |

## Integration with CI/CD

### GitHub Actions

```yaml
name: Weekly Audit

on:
  schedule:
    - cron: '0 9 * * 1'  # Every Monday at 9 AM
  workflow_dispatch:

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup GitHub CLI
        run: |
          sudo apt-get update
          sudo apt-get install -y gh jq

      - name: Authenticate
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: echo "$GH_TOKEN" | gh auth login --with-token

      - name: Run Audit
        run: ./scripts/audit-repos.sh
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

if git diff --cached --name-only | grep -q "config/repositories.json"; then
    echo "🔍 Running quick check before commit..."
    ./scripts/quick-check.sh
fi
```

## Troubleshooting

### "gh: command not found"
```bash
# Install GitHub CLI
# See: https://cli.github.com/
```

### "jq: command not found"
```bash
# Arch Linux
sudo pacman -S jq

# Ubuntu/Debian
sudo apt-get install jq
```

### "Not authenticated with GitHub"
```bash
gh auth login
# Follow prompts
```

### "config/repositories.json not found"
```bash
# Run scripts from UPMAutoPublisher root
cd /mnt/Work/1M/UPM/The1Studio/UPMAutoPublisher
./scripts/audit-repos.sh
```

## Maintenance

### Updating Scripts

Scripts are in git - update like any code:
```bash
# Edit script
nano scripts/audit-repos.sh

# Test changes
./scripts/audit-repos.sh

# Commit
git add scripts/audit-repos.sh
git commit -m "Update audit script"
git push
```

### Adding New Scripts

1. Create script in `scripts/` directory
2. Make executable: `chmod +x scripts/new-script.sh`
3. Document in this README
4. Test thoroughly
5. Commit and push

## Best Practices

1. **Run audit-repos.sh weekly** - Catch issues early
2. **Run quick-check.sh daily** - Quick status awareness
3. **Check single repo when debugging** - Focused investigation
4. **Automate with CI/CD** - Regular scheduled audits
5. **Review recommendations** - Act on audit suggestions

## Related Documentation

- [Quick Registration Guide](../docs/quick-registration.md)
- [Detection Methods](../docs/detection-methods.md)
- [Troubleshooting](../docs/troubleshooting.md)

## Support

For issues with scripts:
1. Check prerequisites are installed
2. Verify GitHub authentication
3. Run from correct directory
4. Check script permissions
5. Review script output for specific errors

---

**Quick Reference:**
```bash
# Full audit (recommended)
./scripts/audit-repos.sh

# Quick table view
./scripts/quick-check.sh

# Check single repo
./scripts/check-single-repo.sh RepoName
```
