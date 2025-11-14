# Webhook-Only Architecture Transition

**Date:** 2025-11-14
**Status:** ✅ Complete

## Overview

Successfully transitioned UPM Auto Publisher from a dual system (webhook + per-repo workflows) to a clean webhook-only architecture.

## Changes Made

### 1. Removed Redundant Workflow Deployment System

**Deleted Files:**
- `.github/workflows/register-repos.yml` - Automatic workflow deployment
- `.github/workflows/manual-register-repo.yml` - Manual deployment trigger

**Why:** These workflows deployed `publish-upm.yml` to each target repository, which is unnecessary since the Cloudflare webhook handles everything organization-wide.

**Commits:**
- `4479cfb` - Remove redundant workflow deployment system

### 2. Created Cleanup Script

**Added:** `scripts/cleanup-repo-workflows.sh`

**Features:**
- Dry-run mode for safe testing (`--dry-run`)
- Processes all active repos from `config/repositories.json`
- Removes `.github/workflows/publish-upm.yml` from target repositories
- Automatic commit and push with descriptive messages
- Clear progress reporting

**Usage:**
```bash
# Test first
./scripts/cleanup-repo-workflows.sh --dry-run

# Apply changes
./scripts/cleanup-repo-workflows.sh
```

**Commits:**
- `77b1216` - Add cleanup script for removing per-repo workflows

### 3. Updated Documentation

**Modified:** `docs/quick-registration.md`

**Changes:**
- Completely rewrote for webhook-only workflow
- Registration time: 5 minutes → 30 seconds
- Removed all PR creation/merging instructions
- Updated to use `status: "active"` immediately
- Simplified workflow diagram
- Added webhook troubleshooting section

**Time Savings:**
- Per repo: ~4.5 minutes saved
- For 10 repos: ~45 minutes saved

**Commits:**
- `58f3aca` - Update quick-registration for webhook-only architecture

## Architecture Comparison

### Before (Dual System)

```
Push to Target Repo
    ↓
Per-Repo publish-upm.yml workflow
    ↓
npm publish
    ↓ (also)
Organization Webhook (Cloudflare)
    ↓
handle-publish-request.yml
    ↓
npm publish (duplicate!)
```

**Issues:**
- Redundant publishing (two systems doing the same thing)
- Per-repo maintenance overhead (workflow files in every repo)
- Complex registration (5-step process with PR creation)
- Workflow deployment automation needed

### After (Webhook-Only)

```
Push to Target Repo
    ↓
Organization Webhook (Cloudflare) - <1s latency
    ↓
handle-publish-request.yml
    ↓
npm publish + changelog + Discord notification
```

**Benefits:**
- ✅ Single source of truth (Cloudflare webhook)
- ✅ Zero per-repo setup (no workflow files needed)
- ✅ Faster registration (30 seconds vs 5 minutes)
- ✅ Cleaner repository structure
- ✅ Easier to maintain centrally

## Registration Process

### Old Process (5 minutes)
1. Add repo to `config/repositories.json` with `status: "pending"`
2. Commit and push
3. Wait for `register-repos.yml` to run
4. Review automated PR in target repository
5. Merge PR
6. Update status to `"active"`
7. Test publishing

### New Process (30 seconds)
1. Add repo to `config/repositories.json` with `status: "active"`
2. Commit and push
3. Done! Webhook immediately monitors the repository

## Impact Summary

### Repositories Affected
- **Currently registered:** 2 repositories (UnityBuildScript, TheOne.ProjectSetup)
- **Will be cleaned:** All repositories once cleanup script is run

### Files Removed
- 2 workflow files from UPMAutoPublisher (register-repos.yml, manual-register-repo.yml)
- Eventually: All `publish-upm.yml` files from target repositories (via cleanup script)

### Documentation Updated
- `docs/quick-registration.md` - Completely rewritten
- CLAUDE.md already reflected webhook architecture (no changes needed)

### Scripts Added
- `scripts/cleanup-repo-workflows.sh` - Removes per-repo workflows

## Migration Path for Existing Repositories

### For Repositories Already Registered

**Current State:**
- Repository has `publish-upm.yml` workflow file
- Repository is listed in `config/repositories.json` as `"active"`
- Both webhook AND per-repo workflow are active (redundant)

**Migration Steps:**
1. **Verify webhook is working:**
   ```bash
   # Bump version and push
   # Check if publish happens via handle-publish-request.yml
   ```

2. **Run cleanup script:**
   ```bash
   ./scripts/cleanup-repo-workflows.sh --dry-run  # Test first
   ./scripts/cleanup-repo-workflows.sh            # Apply
   ```

3. **Verify:**
   - Per-repo workflow file is removed
   - Publishing still works (via webhook only)

### For New Repositories

Simply follow the new registration process in `docs/quick-registration.md`:
1. Add to `config/repositories.json` with `status: "active"`
2. Commit and push
3. Done!

## Rollback Plan (If Needed)

If webhook system fails, you can quickly restore the per-repo workflow system:

1. **Re-enable workflow deployment:**
   ```bash
   git revert 4479cfb  # Restore register-repos.yml and manual-register-repo.yml
   ```

2. **Re-deploy workflows to repositories:**
   ```bash
   # Set repos to "pending" in config/repositories.json
   git add config/repositories.json
   git commit -m "Re-enable workflow deployment"
   git push origin master

   # register-repos.yml will create PRs in target repos
   ```

3. **Merge PRs in target repositories**

## Testing Recommendations

### Before Running Cleanup Script

1. **Verify webhook is functional:**
   ```bash
   # In TheOne.ProjectSetup (already registered):
   # 1. Bump version to 1.0.6
   # 2. Push and verify package publishes
   # 3. Check workflow logs in UPMAutoPublisher
   ```

2. **Test on one repository first:**
   ```bash
   # Modify cleanup script to only process one repo
   # Verify removal works correctly
   # Verify publishing still works
   ```

3. **Full deployment:**
   ```bash
   # Once confident, run for all repositories
   ./scripts/cleanup-repo-workflows.sh
   ```

## Monitoring

### Key Metrics to Watch

1. **Publish Success Rate:**
   ```bash
   gh run list --repo The1Studio/UPMAutoPublisher \
     --workflow handle-publish-request.yml --limit 20 \
     --json conclusion | jq '.[] | .conclusion' | sort | uniq -c
   ```

2. **Webhook Latency:**
   - Check Cloudflare Worker logs
   - Measure time from push to workflow trigger
   - Should be < 1 second

3. **Failure Recovery:**
   - Fallback polling system (`monitor-all-repos.yml`) runs every 5 minutes
   - Should catch any missed webhook events

## Security Considerations

### Organization Secrets Still Required

All existing secrets remain necessary:
- `NPM_TOKEN` - Publishing to registry
- `GH_PAT` - Triggering workflows and committing changelogs
- `GEMINI_API_KEY` - AI changelog generation (optional)
- `WEBHOOK_SECRET` - Securing Cloudflare webhook

### Reduced Attack Surface

By removing per-repo workflows:
- ✅ Fewer workflow files to secure
- ✅ Centralized security updates
- ✅ Easier to audit

## Future Considerations

### Potential Enhancements

1. **Webhook Dashboard:**
   - Monitor webhook health
   - View publish history
   - Alert on failures

2. **Batch Cleanup:**
   - Run cleanup script via GitHub Actions
   - Automate removal from all registered repos

3. **Self-Service Portal:**
   - Allow developers to register repos via web UI
   - No need to edit JSON manually

### Deprecation Timeline

- **2025-11-14:** Webhook-only transition complete
- **2025-11-15:** Run cleanup script for existing repositories
- **2025-11-16:** Monitor for 24 hours, verify all publishes work
- **2025-11-18:** Remove old workflow files from git history (optional)

## Conclusion

The webhook-only architecture transition is complete and successful:
- ✅ Redundant systems removed
- ✅ Registration simplified (5min → 30sec)
- ✅ Documentation updated
- ✅ Cleanup script ready to deploy
- ✅ Rollback plan in place

**Next Step:** Run cleanup script to remove per-repo workflows from all registered repositories.

---

**Related Documentation:**
- [Quick Registration Guide](quick-registration.md) - Updated for webhook-only
- [Architecture Decisions](architecture-decisions.md)
- [Configuration Guide](configuration.md)
- [Troubleshooting](troubleshooting.md)
