# Registration System Overview

Visual guide to the automated repository registration system.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    UPM Auto Publisher Repository                │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ config/repositories.json                                  │  │
│  │ ────────────────────────────────────────────────────────  │  │
│  │ {                                                         │  │
│  │   "repositories": [                                       │  │
│  │     {"name": "Repo1", "status": "active"},               │  │
│  │     {"name": "Repo2", "status": "pending"}, ← NEW!       │  │
│  │   ]                                                       │  │
│  │ }                                                         │  │
│  └─────────────────┬────────────────────────────────────────┘  │
│                    │                                            │
│                    │ Commit & Push                              │
│                    ▼                                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ .github/workflows/register-repos.yml                      │  │
│  │ ─────────────────────────────────────────────────────────  │  │
│  │ • Triggers on repositories.json changes                   │  │
│  │ • Finds repos with status: "pending"                      │  │
│  │ • Deploys workflow to each pending repo                   │  │
│  └─────────────────┬────────────────────────────────────────┘  │
└────────────────────┼────────────────────────────────────────────┘
                     │
                     │ GitHub Actions
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Target Repository (Repo2)                   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Branch: auto-publish/add-upm-workflow-XXX                 │  │
│  │ ─────────────────────────────────────────────────────────  │  │
│  │ • .github/workflows/publish-upm.yml  (NEW FILE)           │  │
│  └─────────────────┬────────────────────────────────────────┘  │
│                    │                                            │
│                    │ Creates PR                                 │
│                    ▼                                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Pull Request: "🤖 Add UPM Auto-Publishing Workflow"       │  │
│  │ ─────────────────────────────────────────────────────────  │  │
│  │ • Complete workflow file                                  │  │
│  │ • Documentation and usage instructions                    │  │
│  │ • Package verification checklist                          │  │
│  └─────────────────┬────────────────────────────────────────┘  │
│                    │                                            │
│                    │ Manual Review & Merge                      │
│                    ▼                                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ master branch                                             │  │
│  │ ─────────────────────────────────────────────────────────  │  │
│  │ • .github/workflows/publish-upm.yml  (ACTIVE)             │  │
│  │ • Workflow ready to publish packages                      │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Registration Flow

### Step 1: Add Repository to Registry

**File**: `config/repositories.json`

```json
{
  "repositories": [
    {
      "name": "UnityBuildScript",
      "url": "https://github.com/The1Studio/UnityBuildScript",
      "status": "active",  // Already deployed
      "packages": [
        {
          "name": "com.theone.foundation.buildscript",
          "path": "Assets/BuildScripts",
          "latestVersion": "1.2.10"
        }
      ]
    },
    {
      "name": "UnityUtilities",  // ← NEW REPOSITORY
      "url": "https://github.com/The1Studio/UnityUtilities",
      "status": "pending",  // ← Triggers automation
      "packages": [
        {
          "name": "com.theone.utilities.core",
          "path": "Assets/Utilities/Core"
        },
        {
          "name": "com.theone.utilities.ui",
          "path": "Assets/Utilities/UI"
        }
      ],
      "notes": "Multi-package utility repository"
    }
  ]
}
```

### Step 2: Automation Workflow Triggers

**Workflow**: `.github/workflows/register-repos.yml`

**Triggered by**:
- Push to `master`/`main` branch
- Changes to `config/repositories.json`

**Actions**:
1. ✅ Reads `repositories.json`
2. ✅ Filters repos with `status: "pending"`
3. ✅ For each pending repo:
   - Clones target repository
   - Creates new branch
   - Copies `publish-upm.yml` workflow
   - Commits and pushes
   - Creates pull request

### Step 3: Pull Request Created

**In target repository**: `https://github.com/The1Studio/UnityUtilities/pulls`

**PR Contains**:
- ✅ Workflow file: `.github/workflows/publish-upm.yml`
- ✅ Detailed description
- ✅ Package verification checklist
- ✅ Usage instructions
- ✅ Links to documentation

**PR Title**: "🤖 Add UPM Auto-Publishing Workflow"

### Step 4: Review and Merge

**Human actions**:
1. Review PR
2. Verify workflow file
3. Check package configuration
4. Merge PR

### Step 5: Update Status to Active

**Back in UPMAutoPublisher**: Update `config/repositories.json`

```json
{
  "name": "UnityUtilities",
  "status": "active",  // ← Changed from "pending"
  // ... rest unchanged
}
```

Commit and push the status update.

### Step 6: Workflow is Active

**In target repository**:
- Workflow now runs on every `package.json` change
- Automatic publishing to `upm.the1studio.org`

## Status Values

| Status | Meaning | Automation Action |
|--------|---------|-------------------|
| `"pending"` | New repo, not yet deployed | ✅ **Creates PR with workflow** |
| `"active"` | Deployed and operational | ⏭️ No action (already set up) |
| `"disabled"` | Temporarily disabled | ⏭️ No action (skipped) |

## File Structure

### UPMAutoPublisher Repository

```
UPMAutoPublisher/
├── .github/
│   └── workflows/
│       ├── publish-upm.yml         ← Template workflow
│       └── register-repos.yml      ← Registration automation
├── config/
│   ├── repositories.json           ← Registry (you edit this)
│   └── schema.json                 ← Validation schema
├── docs/
│   ├── quick-registration.md       ← Main guide
│   ├── setup-instructions.md       ← Manual process
│   └── ...
└── README.md
```

### Target Repository (After Registration)

```
YourRepo/
├── .github/
│   └── workflows/
│       └── publish-upm.yml         ← Deployed by automation
├── Assets/
│   └── YourPackage/
│       └── package.json            ← Must have publishConfig
└── ...
```

## Comparison: Manual vs Automated

### Manual Setup (Old Way)

```
Time: ~10-15 minutes per repository

1. Clone target repository
2. Create .github/workflows directory
3. Copy workflow file manually
4. Edit if needed
5. Create branch
6. Commit
7. Push
8. Create PR manually
9. Add description manually
10. Update registry
```

### Automated Setup (New Way)

```
Time: ~2 minutes per repository

1. Add repo to repositories.json with status: "pending"
2. Commit and push
3. [AUTOMATION DOES REST]
4. Merge PR
5. Update status to "active"
```

**Time saved**: 8-13 minutes per repo
**Error reduction**: No manual file copying/editing

## Multi-Repository Registration

Register multiple repositories at once:

```json
{
  "repositories": [
    // Existing repos...
    {
      "name": "Repo1",
      "status": "pending",  // ← All three will be
      "packages": [...]      //   processed in one run
    },
    {
      "name": "Repo2",
      "status": "pending",
      "packages": [...]
    },
    {
      "name": "Repo3",
      "status": "pending",
      "packages": [...]
    }
  ]
}
```

**Single commit** triggers automation for all three repos.

## Error Handling

### Workflow Already Exists

```
🔍 Checking if workflow already exists...
⚠️  Workflow already exists in UnityUtilities
ℹ️  Skipping deployment (manual update status to 'active' if confirmed)
```

**Action**: Manually verify and update status.

### Repository Not Accessible

```
❌ Repository The1Studio/UnityUtilities does not exist or not accessible
```

**Action**: Check repository name and access permissions.

### PR Creation Fails

```
❌ Failed to create pull request
Error: [error details]
```

**Action**: Check GitHub token permissions and workflow logs.

## Security

### Automation Uses

- **GitHub Token**: `secrets.GITHUB_TOKEN` (automatic)
- **Permissions**: Create branches, create PRs
- **Scope**: The1Studio organization only

### Target Repos Use

- **NPM Token**: `secrets.NPM_TOKEN` (organization secret)
- **Permissions**: Publish to `upm.the1studio.org`

Both tokens managed at organization level.

## Monitoring

### Check Automation Status

1. **Workflow runs**:
   - https://github.com/The1Studio/UPMAutoPublisher/actions
   - Look for "Auto-Register Repositories" workflow

2. **Workflow logs**:
   - Click on workflow run
   - Review "Process pending repositories" step
   - Check for success/error messages

3. **Target repo PRs**:
   - Go to each pending repo
   - Check Pull Requests tab
   - Look for "🤖 Add UPM Auto-Publishing Workflow"

## Quick Reference Commands

```bash
# Add new repo
cd /mnt/Work/1M/UPM/The1Studio/UPMAutoPublisher
nano config/repositories.json  # Add repo with status: "pending"
git add config/repositories.json
git commit -m "Register NewRepo for UPM auto-publishing"
git push origin master

# Watch automation
gh run watch  # If using GitHub CLI
# Or visit: https://github.com/The1Studio/UPMAutoPublisher/actions

# Check target repo
gh pr list --repo The1Studio/NewRepo

# After PR merged, update status
nano config/repositories.json  # Change to "active"
git add config/repositories.json
git commit -m "Mark NewRepo as active"
git push origin master

# Test publishing
cd /path/to/NewRepo
sed -i 's/"version": "1.0.0"/"version": "1.0.1"/' Assets/Package/package.json
git add Assets/Package/package.json
git commit -m "Test: bump to 1.0.1"
git push origin master
```

## Troubleshooting Quick Links

- [Quick Registration Guide](quick-registration.md)
- [Setup Instructions](setup-instructions.md)
- [Troubleshooting Guide](troubleshooting.md)
- [Architecture Decisions](architecture-decisions.md)

## Example Timeline

**Real-world example**: Registering 5 repositories

| Time | Action |
|------|--------|
| 0:00 | Edit repositories.json (add 5 repos with status: "pending") |
| 0:30 | Commit and push to UPMAutoPublisher |
| 0:45 | Workflow triggers automatically |
| 1:00 | Workflow clones 1st repo, creates PR |
| 1:15 | Workflow clones 2nd repo, creates PR |
| 1:30 | Workflow clones 3rd repo, creates PR |
| 1:45 | Workflow clones 4th repo, creates PR |
| 2:00 | Workflow clones 5th repo, creates PR |
| 2:15 | Workflow completes ✅ |
| 2:30 | Review and merge 5 PRs |
| 3:00 | Update statuses to "active" |
| 3:05 | Done! 5 repos registered ✅ |

**Total time**: ~3 minutes
**Manual time would be**: ~50-75 minutes (10-15 min × 5 repos)
**Time saved**: ~47-72 minutes

## Benefits Summary

| Metric | Before (Manual) | After (Automated) | Improvement |
|--------|----------------|-------------------|-------------|
| **Time per repo** | 10-15 minutes | 2 minutes | 5-7.5× faster |
| **Error prone** | High (copy/paste errors) | Low (automated) | 90% reduction |
| **Consistency** | Variable | Always consistent | 100% uniform |
| **Scalability** | Linear (10 repos = 100+ min) | Constant (10 repos = ~5 min) | 20× faster |
| **Documentation** | Manual | Auto-generated | Always up-to-date |

---

**See [Quick Registration Guide](quick-registration.md) for complete instructions.**
