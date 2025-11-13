# Migration to workflow_call Pattern

**⚠️ DEPRECATED:** This approach is superseded by the **organization webhook** solution.

**Date:** 2025-11-13
**Status:** ⛔ DEPRECATED - Use webhook approach instead
**Replacement:** [Webhook Setup Guide](./webhook-setup-guide.md)

**Why deprecated:**
- Webhook approach requires **zero setup** in target repos (workflow_call requires updating each repo)
- Webhook is **event-driven** with <1s latency (workflow_call still has dispatch delay)
- Webhook is **simpler** (no workflow file changes needed)

**If you still want workflow_call:** See legacy template in `templates/` directory.

---

## Original Documentation (For Reference Only)

---

## 🎯 Problem Being Solved

The previous `repository_dispatch` pattern had a **critical reliability issue**:

### What Went Wrong (2025-11-13 Incident)

1. ✅ PR #979 merged in TheOneFeature at 11:50:04Z
2. ✅ Dispatcher workflow triggered at 11:50:07Z
3. ✅ Changes detected (2 package.json files)
4. ✅ `repository_dispatch` event sent at 11:50:23Z
5. ❌ **handle-publish-request.yml NEVER triggered**

### Root Cause

`repository_dispatch` events are **"best effort" delivery** in GitHub Actions:
- Events can be silently dropped during high load
- No retry mechanism
- No failure notification
- Can fail if GitHub Actions queue is congested

**Result:** Packages with version bumps didn't get published, breaking the automation.

---

## ✨ New Solution: `workflow_call` Pattern

### Architecture

```
┌─────────────────────────────────────┐
│  TheOneFeature Repository           │
│                                      │
│  ┌────────────────────────────────┐ │
│  │ upm-publish-dispatcher.yml     │ │
│  │ Detects package.json changes   │ │
│  └────────────────┬───────────────┘ │
│                   │                  │
└───────────────────┼──────────────────┘
                    │
                    │ workflow_call (synchronous, reliable)
                    │
┌───────────────────▼──────────────────┐
│  UPMAutoPublisher Repository         │
│                                       │
│  ┌─────────────────────────────────┐│
│  │ handle-publish-request-         ││
│  │   reusable.yml                  ││
│  │ - Validates repo is registered  ││
│  │ - Publishes packages            ││
│  │ - Sends Discord notification    ││
│  └─────────────────────────────────┘│
│                                       │
└───────────────────────────────────────┘
```

### Key Improvements

| Feature | `repository_dispatch` (OLD) | `workflow_call` (NEW) |
|---------|----------------------------|----------------------|
| **Reliability** | ❌ Best effort, can fail silently | ✅ Guaranteed execution or visible error |
| **Visibility** | ❌ No way to know if dispatch failed | ✅ Shows as dependent job in workflow UI |
| **Debugging** | ❌ Hard to debug (no logs if not triggered) | ✅ Full logs visible in calling workflow |
| **Speed** | ⚠️ Asynchronous (3-30 seconds delay) | ✅ Synchronous (immediate) |
| **Error Handling** | ❌ Silent failures | ✅ Caller sees failures immediately |
| **Secrets** | ⚠️ Must be org secrets | ✅ Can use repo or org secrets |

---

## 📦 What Changed

### New Files Created

1. **`.github/workflows/handle-publish-request-reusable.yml`**
   - Reusable workflow version of handle-publish-request
   - Accepts inputs via `workflow_call`
   - Validates calling repo is registered in config/repositories.json
   - Identical logic to original, but callable

2. **`.github/workflows/upm-publish-dispatcher-template.yml`**
   - Updated dispatcher template for registered repos
   - Uses `workflow_call` instead of `repository_dispatch`
   - Shows detected changes as workflow job dependency

### Files to Update in Each Repo

Each registered repository needs to update their dispatcher workflow from:

**OLD (repository_dispatch):**
```yaml
- name: Dispatch to UPMAutoPublisher
  run: |
    jq -n ... | gh api /repos/The1Studio/UPMAutoPublisher/dispatches --input -
  env:
    GH_TOKEN: ${{ secrets.GH_PAT || secrets.GITHUB_TOKEN }}
```

**NEW (workflow_call):**
```yaml
jobs:
  publish:
    needs: detect-and-dispatch
    if: needs.detect-and-dispatch.outputs.has_changes == 'true'
    uses: The1Studio/UPMAutoPublisher/.github/workflows/handle-publish-request-reusable.yml@master
    with:
      repository: ${{ github.repository }}
      commit_sha: ${{ github.sha }}
      commit_message: ${{ github.event.head_commit.message }}
      commit_author: ${{ github.event.head_commit.author.username }}
      branch: ${{ github.ref_name }}
      package_path: ''
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
      DISCORD_WEBHOOK_UPM: ${{ secrets.DISCORD_WEBHOOK_UPM }}
      GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
      GH_PAT: ${{ secrets.GH_PAT }}
```

---

## 🚀 Migration Steps

### Phase 1: Deploy Reusable Workflow (✅ DONE)

1. ✅ Created `handle-publish-request-reusable.yml`
2. ✅ Added repository validation (checks config/repositories.json)
3. ✅ Tested with local dispatcher

### Phase 2: Update Registered Repositories

For each repository in `config/repositories.json` with status "active":

#### 2.1 Update TheOneFeature (PRIORITY - Has Unpublished Packages)

```bash
# 1. Clone repository
git clone git@github.com:The1Studio/TheOneFeature.git
cd TheOneFeature

# 2. Create branch
git checkout -b feat/migrate-to-workflow-call

# 3. Copy new dispatcher template
curl -fsSL https://raw.githubusercontent.com/The1Studio/UPMAutoPublisher/master/.github/workflows/upm-publish-dispatcher-template.yml \
  -o .github/workflows/upm-publish-dispatcher.yml

# 4. Commit and push
git add .github/workflows/upm-publish-dispatcher.yml
git commit -m "feat: migrate to workflow_call pattern for reliable UPM publishing"
git push origin feat/migrate-to-workflow-call

# 5. Create PR and merge
gh pr create --title "Migrate to workflow_call pattern" \
  --body "Migrates from repository_dispatch to workflow_call for more reliable package publishing"
```

#### 2.2 Update UnityBuildScript

```bash
cd /mnt/Work/1M/1.OneTools/UPM/The1Studio/UnityBuildScript

# Check if dispatcher exists
if [ -f .github/workflows/upm-publish-dispatcher.yml ]; then
  # Update existing dispatcher
  curl -fsSL https://raw.githubusercontent.com/The1Studio/UPMAutoPublisher/master/.github/workflows/upm-publish-dispatcher-template.yml \
    -o .github/workflows/upm-publish-dispatcher.yml

  git add .github/workflows/upm-publish-dispatcher.yml
  git commit -m "feat: migrate to workflow_call pattern"
  git push
else
  echo "⚠️  No dispatcher workflow found - needs manual setup"
fi
```

#### 2.3 Bulk Update Script

```bash
# Script to update all registered repositories
#!/bin/bash

# Read registered repos from config
repos=$(jq -r '.[] | select(.status == "active") | .url' config/repositories.json | sed 's|https://github.com/||')

for repo in $repos; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📦 Processing: $repo"

  # Clone repo
  temp_dir=$(mktemp -d)
  git clone "git@github.com:$repo.git" "$temp_dir" 2>/dev/null || {
    echo "❌ Failed to clone $repo"
    continue
  }

  cd "$temp_dir"

  # Check if dispatcher exists
  if [ -f .github/workflows/upm-publish-dispatcher.yml ]; then
    echo "✅ Found dispatcher workflow"

    # Create branch
    git checkout -b feat/migrate-to-workflow-call

    # Download new template
    curl -fsSL https://raw.githubusercontent.com/The1Studio/UPMAutoPublisher/master/.github/workflows/upm-publish-dispatcher-template.yml \
      -o .github/workflows/upm-publish-dispatcher.yml

    # Commit and push
    git add .github/workflows/upm-publish-dispatcher.yml
    git commit -m "feat: migrate to workflow_call pattern for reliable UPM publishing"
    git push origin feat/migrate-to-workflow-call

    # Create PR
    gh pr create --title "Migrate to workflow_call pattern" \
      --body "Migrates from repository_dispatch to workflow_call for more reliable package publishing. See: https://github.com/The1Studio/UPMAutoPublisher/blob/master/docs/workflow-call-migration.md"

    echo "✅ PR created for $repo"
  else
    echo "⏭️  No dispatcher workflow in $repo"
  fi

  cd -
  rm -rf "$temp_dir"
done
```

### Phase 3: Deprecate Old Pattern

After all repos migrated:

1. Update `handle-publish-request.yml` to show deprecation warning
2. Keep both patterns working for 30 days
3. Remove `repository_dispatch` trigger after grace period

---

## 🧪 Testing

### Test in TheOneFeature

1. **Create test branch:**
   ```bash
   cd TheOneFeature
   git checkout -b test/workflow-call-pattern
   ```

2. **Bump a package version:**
   ```bash
   # Edit any package.json
   cd Core/Adapters
   npm version patch
   git add package.json
   git commit -m "test: bump version to test workflow_call"
   git push origin test/workflow-call-pattern
   ```

3. **Verify workflow runs:**
   - Check TheOneFeature Actions tab
   - Should see "UPM Publish Dispatcher" workflow
   - Should see nested "publish" job
   - Logs should be visible inline

4. **Verify package published:**
   ```bash
   npm view @the1.packages/core.adapters --registry https://upm.the1studio.org/
   ```

### Expected Behavior

**OLD (repository_dispatch):**
```
TheOneFeature workflow:
├─ Detect changes ✅
└─ Dispatch sent ✅

UPMAutoPublisher workflow:
└─ ❓ May or may not trigger (invisible failure)
```

**NEW (workflow_call):**
```
TheOneFeature workflow:
├─ Detect changes ✅
└─ Publish (calls UPMAutoPublisher)
    ├─ Validate repo is registered ✅
    ├─ Clone target repo ✅
    ├─ Publish packages ✅
    └─ Send Discord notification ✅
```

---

## 📊 Benefits

### Reliability
- ✅ **100% delivery guarantee** (or visible error)
- ✅ **No silent failures** like the 11:50 incident
- ✅ **Immediate feedback** if publish fails

### Visibility
- ✅ **Full logs** in calling workflow
- ✅ **Job dependencies** shown in UI
- ✅ **Clear error messages** if validation fails

### Debugging
- ✅ **Easier to troubleshoot** (all logs in one place)
- ✅ **See exactly which step failed**
- ✅ **Can re-run failed jobs**

### Security
- ✅ **Repository validation** built-in
- ✅ **Only registered repos** can trigger publishes
- ✅ **Secrets properly passed** through workflow_call

---

## ⚠️ Migration Checklist

### UPMAutoPublisher Repository
- [x] Create `handle-publish-request-reusable.yml`
- [x] Add repository validation logic
- [x] Test with sample inputs
- [ ] Deploy to master branch

### Each Registered Repository
- [ ] Update dispatcher workflow to use workflow_call
- [ ] Test with version bump
- [ ] Verify publish works
- [ ] Verify Discord notification sent

### Documentation
- [x] Create migration guide (this document)
- [ ] Update main README.md
- [ ] Update CLAUDE.md
- [ ] Update troubleshooting guide

---

## 🔄 Rollback Plan

If issues occur during migration:

1. **Single repo issue:** Revert that repo's dispatcher to old pattern
2. **Reusable workflow issue:** Fix in UPMAutoPublisher, redeploy
3. **Critical failure:** Keep old `handle-publish-request.yml` as fallback

**Grace Period:** Both patterns will work simultaneously for 30 days.

---

## 📚 References

- [GitHub Actions: Reusing workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [workflow_call trigger](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#workflow_call)
- [Incident: 2025-11-13 Silent Dispatch Failure](../docs/troubleshooting.md#repository_dispatch-not-triggering)

---

**Status:** ✅ Reusable workflow created, ready for migration
**Next Step:** Test in TheOneFeature, then roll out to all registered repos
**Estimated Time:** 1-2 hours for all repositories
**Risk Level:** LOW (can run both patterns in parallel during migration)
