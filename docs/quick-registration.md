# Quick Repository Registration Guide

**🎯 Goal**: Register a new repository for UPM auto-publishing in under 2 minutes.

## TL;DR - The Fast Way

```bash
# 1. Add repo to config/repositories.json with status: "pending"
# 2. Commit and push
# 3. GitHub Action creates PR in target repo automatically
# 4. Merge PR
# 5. Change status to "active"
```

---

## Step-by-Step Registration

### Step 1: Add Repository to Registry (30 seconds)

Edit `config/repositories.json` in the UPMAutoPublisher repo:

```json
{
  "repositories": [
    {
      "name": "YourNewRepo",
      "url": "https://github.com/The1Studio/YourNewRepo",
      "status": "pending",  // ⚠️ Important: Set to "pending"
      "packages": [
        {
          "name": "com.theone.yourpackage",
          "path": "Assets/YourPackage"
        }
      ],
      "notes": "Your optional notes here"
    }
  ]
}
```

**For multi-package repos:**
```json
{
  "name": "UnityUtilities",
  "url": "https://github.com/The1Studio/UnityUtilities",
  "status": "pending",
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
```

### Step 2: Commit and Push (10 seconds)

```bash
cd /mnt/Work/1M/UPM/The1Studio/UPMAutoPublisher

git add config/repositories.json
git commit -m "Register YourNewRepo for UPM auto-publishing"
git push origin master
```

### Step 3: Wait for Automation (1-2 minutes)

GitHub Action automatically:
1. ✅ Detects new `"pending"` repository
2. ✅ Clones the target repository
3. ✅ Creates workflow file `.github/workflows/publish-upm.yml`
4. ✅ Creates a pull request in the target repo
5. ✅ Adds helpful comments and documentation

**Monitor progress:**
- https://github.com/The1Studio/UPMAutoPublisher/actions

### Step 4: Review and Merge PR (30 seconds)

Go to the target repository:
- **URL**: `https://github.com/The1Studio/YourNewRepo/pulls`

You'll see a PR titled: **"🤖 Add UPM Auto-Publishing Workflow"**

**Review checklist** (automated PR includes this):
- [ ] Workflow file looks correct
- [ ] Package paths are accurate
- [ ] `package.json` has `publishConfig.registry: https://upm.the1studio.org/`

**Merge the PR**

### Step 5: Update Status to Active (20 seconds)

After PR is merged, update the status in `repositories.json`:

```bash
cd /mnt/Work/1M/UPM/The1Studio/UPMAutoPublisher

# Edit config/repositories.json
# Change: "status": "pending" → "status": "active"
```

```json
{
  "name": "YourNewRepo",
  "status": "active",  // ✅ Changed from "pending"
  // ... rest of config
}
```

```bash
git add config/repositories.json
git commit -m "Mark YourNewRepo as active"
git push origin master
```

### Step 6: Test It (1 minute)

In the target repo, make a test version bump:

```bash
cd /path/to/YourNewRepo

# Bump version
sed -i 's/"version": "1.0.0"/"version": "1.0.1"/' Assets/YourPackage/package.json

# Commit and push
git add Assets/YourPackage/package.json
git commit -m "Test UPM auto-publish: bump to 1.0.1"
git push origin master
```

**Watch the workflow run:**
- Go to: `https://github.com/The1Studio/YourNewRepo/actions`
- Look for: "Publish to UPM Registry" workflow

**Verify published:**
```bash
npm view com.theone.yourpackage@1.0.1 --registry https://upm.the1studio.org/
```

---

## Complete Example

```json
// config/repositories.json
{
  "repositories": [
    {
      "name": "UnityBuildScript",
      "url": "https://github.com/The1Studio/UnityBuildScript",
      "status": "active",
      "packages": [
        {
          "name": "com.theone.foundation.buildscript",
          "path": "Assets/BuildScripts",
          "latestVersion": "1.2.10"
        }
      ],
      "notes": "First repository with auto-publishing"
    },
    {
      "name": "UnityUtilities",  // ← NEW REPO
      "url": "https://github.com/The1Studio/UnityUtilities",
      "status": "pending",  // ← Will trigger automation
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

---

## What the Automation Does

### Creates This Workflow File

The automation creates `.github/workflows/publish-upm.yml` in the target repo:

```yaml
name: Publish to UPM Registry

on:
  push:
    branches: [master, main]
    paths: ['**/package.json']

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      # ... (complete workflow from template)
```

### Creates a PR With:

- ✅ Workflow file
- ✅ Detailed description
- ✅ Package verification checklist
- ✅ Links to documentation
- ✅ Usage instructions

---

## Repository Status Values

| Status | Meaning | Action |
|--------|---------|--------|
| `"pending"` | **Not yet deployed** | ✅ Automation will create PR |
| `"active"` | **Deployed and working** | ⏭️ No action needed |
| `"disabled"` | **Temporarily disabled** | ⏭️ Automation ignores |

---

## Troubleshooting

### PR Not Created

**Check these:**

1. **Workflow ran successfully?**
   ```
   https://github.com/The1Studio/UPMAutoPublisher/actions
   ```

2. **Workflow already exists?**
   ```bash
   gh api repos/The1Studio/YourRepo/contents/.github/workflows/publish-upm.yml
   ```
   If exists, automation skips (manual update needed)

3. **Repository accessible?**
   ```bash
   gh repo view The1Studio/YourRepo
   ```

4. **GitHub token has permissions?**
   - Token needs: `repo` scope
   - Organization must allow Actions to create PRs

### Workflow File Already Exists

If `.github/workflows/publish-upm.yml` already exists:

1. Automation will skip the repo
2. Manually update the workflow file if needed
3. Change status to `"active"` in `repositories.json`

### Authentication Errors

Automation uses `secrets.GITHUB_TOKEN` which has limited permissions.

**If PR creation fails:**
- May need Personal Access Token with `repo` scope
- Update workflow to use PAT instead of `GITHUB_TOKEN`

---

## Advanced: Manual Deployment

If automation fails, deploy manually:

```bash
# 1. Clone target repo
git clone https://github.com/The1Studio/YourRepo.git
cd YourRepo

# 2. Create branch
git checkout -b add-upm-workflow

# 3. Copy workflow
mkdir -p .github/workflows
cp /path/to/UPMAutoPublisher/.github/workflows/publish-upm.yml \
   .github/workflows/

# 4. Commit and push
git add .github/workflows/publish-upm.yml
git commit -m "Add UPM auto-publishing workflow"
git push origin add-upm-workflow

# 5. Create PR manually
gh pr create --title "Add UPM Auto-Publishing Workflow" \
  --body "Adds automated UPM publishing"
```

---

## Multi-Repository Registration

Register multiple repos at once:

```json
{
  "repositories": [
    // Existing repos...
    {
      "name": "Repo1",
      "url": "https://github.com/The1Studio/Repo1",
      "status": "pending",
      "packages": [{"name": "com.theone.package1", "path": "Assets/Package1"}]
    },
    {
      "name": "Repo2",
      "url": "https://github.com/The1Studio/Repo2",
      "status": "pending",
      "packages": [{"name": "com.theone.package2", "path": "Assets/Package2"}]
    },
    {
      "name": "Repo3",
      "url": "https://github.com/The1Studio/Repo3",
      "status": "pending",
      "packages": [{"name": "com.theone.package3", "path": "Assets/Package3"}]
    }
  ]
}
```

**Commit once**, automation processes all pending repos.

---

## Package Configuration Requirements

Each target repository **must** have `package.json` configured:

### ✅ Correct Configuration

```json
{
  "name": "com.theone.yourpackage",
  "version": "1.0.0",
  "displayName": "Your Package",
  "description": "Package description",
  "unity": "2022.3",
  "publishConfig": {
    "registry": "https://upm.the1studio.org/"
  }
}
```

### ❌ Missing publishConfig

```json
{
  "name": "com.theone.yourpackage",
  "version": "1.0.0"
  // ❌ Missing publishConfig - workflow will skip publishing
}
```

**Fix before merging PR:**
```bash
cd Assets/YourPackage

# Add publishConfig to package.json
jq '. + {"publishConfig": {"registry": "https://upm.the1studio.org/"}}' \
  package.json > package.json.tmp
mv package.json.tmp package.json

git add package.json
git commit -m "Add publishConfig for UPM registry"
git push
```

---

## Benefits of This System

### Before (Manual Setup)
1. Clone target repo
2. Create workflow file manually
3. Copy/paste template
4. Commit and push
5. Verify workflow
6. Update registry
7. Test publishing

**Time**: ~10-15 minutes per repo

### After (Automated Registration)
1. Add repo to JSON with `status: "pending"`
2. Commit and push
3. Merge automated PR
4. Update status to `"active"`

**Time**: ~2 minutes per repo

**Time saved**: ~8-13 minutes per repo
**For 10 repos**: Saves ~1.5-2 hours!

---

## Security Notes

### Automation Uses

- **GitHub Token**: `secrets.GITHUB_TOKEN` (built-in)
- **Permissions**: Can create PRs in The1Studio repos
- **Scope**: Limited to organization repositories

### Target Repos Need

- **NPM Token**: `secrets.NPM_TOKEN` (organization secret)
- **Permissions**: Can publish to `upm.the1studio.org`

Both should already be configured at organization level.

---

## Workflow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Add repo to repositories.json with status: "pending"    │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Commit and push to UPMAutoPublisher master              │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. GitHub Action "register-repos" triggers                  │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. For each "pending" repo:                                 │
│    - Clone target repository                                │
│    - Create branch: auto-publish/add-upm-workflow-XXX       │
│    - Copy publish-upm.yml workflow                          │
│    - Commit and push                                        │
│    - Create PR with documentation                           │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Review PR in target repository                           │
│    - Check workflow file                                    │
│    - Verify package configuration                           │
│    - Merge PR                                               │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. Update status to "active" in repositories.json           │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 7. Test with version bump in target repo                    │
└─────────────────────────────────────────────────────────────┘
```

---

## FAQ

### Q: Can I register private repositories?
**A:** Yes! Automation works with both public and private repos in The1Studio organization.

### Q: What if the workflow file already exists?
**A:** Automation detects this and skips the repo. Manually update if needed.

### Q: Can I register repos from other organizations?
**A:** No, only repositories in The1Studio organization are supported.

### Q: What happens if I add multiple pending repos at once?
**A:** Automation processes all of them in one run, creating PRs for each.

### Q: Can I test without affecting real repos?
**A:** Yes! Use a test repository and set it to `"pending"` to see the automation in action.

### Q: What if PR creation fails?
**A:** Check the workflow logs in UPMAutoPublisher Actions tab for error details.

---

## Checklist: Ready to Register?

Before registering a new repo, verify:

- [ ] Repository exists in The1Studio organization
- [ ] Package has valid `package.json` file
- [ ] `package.json` has `name` starting with `com.theone.`
- [ ] `package.json` has `version` field
- [ ] `package.json` has `publishConfig.registry: https://upm.the1studio.org/`
- [ ] You have write access to UPMAutoPublisher repo
- [ ] Organization has `NPM_TOKEN` secret configured

---

## Related Documentation

- [Main README](../README.md)
- [Setup Instructions](setup-instructions.md) (manual process)
- [Architecture Decisions](architecture-decisions.md)
- [Troubleshooting](troubleshooting.md)

---

**Need help?** Check workflow logs or create an issue in UPMAutoPublisher repository.
