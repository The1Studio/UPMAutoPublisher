# UPM Auto Publisher: Webhook-Only Architecture Transition Plan

**Date:** 2025-11-14
**Status:** DRAFT
**Priority:** HIGH (Blocking all automation)
**Estimated Time:** 8-16 hours

---

## Executive Summary

**Goal:** Transition to webhook-only architecture where Cloudflare Worker handles ALL package publishing events, eliminating redundant per-repo dispatcher workflows.

**Current State:**
- ❌ Dual system: Cloudflare webhook + per-repo dispatchers (redundant)
- ❌ CRITICAL: ARC runners not picking up ANY jobs (0 jobs executed)
- ❌ `workflow_dispatch` broken (HTTP 422 error from GitHub API)
- ❌ `repository_dispatch` also not triggering runs
- ✅ Cloudflare Worker deployed and functional
- ✅ 24 repos registered, webhook receiving events

**Target State:**
- ✅ Single system: Cloudflare webhook ONLY
- ✅ Per-repo dispatcher workflows REMOVED
- ✅ ARC runners working OR fallback to GitHub-hosted
- ✅ `repository_dispatch` as trigger (NOT workflow_dispatch)
- ✅ Clean, maintainable architecture

**Blockers:**
1. **CRITICAL:** ARC runners completely broken (must fix or fallback first)
2. **HIGH:** Cloudflare Worker using wrong dispatch method
3. **MEDIUM:** Per-repo workflows still deployed (maintenance burden)

---

## Phase 1: Emergency - Fix ARC Runners (CRITICAL)

**Priority:** P0 - BLOCKING EVERYTHING
**Time:** 2-4 hours
**Risk:** HIGH (affects all workflows)

### Problem Analysis

**Symptoms:**
- All workflow runs fail with 0 jobs
- No runner pods picking up queued jobs
- Workflows triggered but never execute

**Potential Root Causes:**
1. Runner pods not healthy (CrashLoopBackOff, ImagePullBackOff)
2. RunnerScaleSet not scaling up
3. Label mismatch (workflow expects `[self-hosted, arc, the1studio, org]`)
4. Listener pod not forwarding jobs
5. Network issues (runners can't reach GitHub API)
6. Authentication failure (GitHub App token expired)

### Investigation Steps

#### 1.1. Check Runner Pods Health

```bash
# Check runner namespace
kubectl get all -n arc-runners

# Expected output:
# - RunnerScaleSet: the1studio-org-runners
# - Listener pod: RUNNING
# - Runner pods: 0-2 (scales on demand)

# Check for errors
kubectl get pods -n arc-runners
kubectl describe pod -n arc-runners <pod-name>

# Check logs
kubectl logs -n arc-runners -l app=runner-scale-set-listener --tail=100
kubectl logs -n arc-runners -l app=runner-scale-set --tail=100
```

**Look for:**
- ❌ CrashLoopBackOff, ImagePullBackOff
- ❌ "Permission denied" errors
- ❌ "Failed to get runner token"
- ❌ Network connectivity issues

#### 1.2. Check RunnerScaleSet Configuration

```bash
# Get RunnerScaleSet details
kubectl get runnerscaleset -n arc-runners the1studio-org-runners -o yaml

# Check critical fields:
# - githubConfigUrl: https://github.com/The1Studio
# - minRunners: 0
# - maxRunners: 3
# - labels: [self-hosted, arc, the1studio, org]
```

#### 1.3. Check Listener Pod

```bash
# Listener forwards jobs from GitHub to runner pods
kubectl get pods -n arc-runners -l app=runner-scale-set-listener

# Check logs for job matching
kubectl logs -n arc-runners -l app=runner-scale-set-listener --tail=200 | grep -i "job\|queue\|runner"
```

#### 1.4. Test GitHub API Connectivity

```bash
# From runner pod (if any are running)
kubectl exec -n arc-runners <runner-pod> -- curl -s https://api.github.com/zen

# From listener pod
kubectl exec -n arc-runners <listener-pod> -- curl -s https://api.github.com/zen
```

### Fix Options

#### Option A: Fix ARC Runners (Preferred)

**If issue is:**

1. **Pods not healthy:**
   ```bash
   # Restart listener
   kubectl rollout restart deployment -n arc-runners

   # Delete failed runner pods
   kubectl delete pod -n arc-runners -l app=runner-scale-set
   ```

2. **GitHub App token expired:**
   ```bash
   # Check GitHub App installation
   gh api /orgs/The1Studio/installations

   # Regenerate credentials (see ARC setup docs)
   ```

3. **Label mismatch:**
   ```yaml
   # Update RunnerScaleSet labels
   kubectl edit runnerscaleset -n arc-runners the1studio-org-runners

   # Ensure labels match workflow:
   labels:
     - self-hosted
     - arc
     - the1studio
     - org
   ```

4. **Scale not working:**
   ```bash
   # Force scale up for testing
   kubectl scale runnerscaleset -n arc-runners the1studio-org-runners --replicas=1

   # Check if pod starts
   kubectl get pods -n arc-runners -w
   ```

**Success Criteria:**
- ✅ Runner pods start and stay RUNNING
- ✅ Pods register with GitHub (check org settings)
- ✅ Test workflow completes successfully

**Test:**
```bash
# Trigger simple workflow
cd /mnt/Work/1M/1.OneTools/UPM/The1Studio/UPMAutoPublisher
gh workflow run handle-publish-request.yml \
  --field repository="The1Studio/TheOneFeature" \
  --field commit_sha="HEAD" \
  --field commit_message="test" \
  --field commit_author="test"

# Watch run
gh run watch
```

#### Option B: Fallback to GitHub-Hosted Runners (Quick Fix)

**If ARC unfixable immediately:**

```yaml
# Update handle-publish-request.yml
jobs:
  publish-packages:
    runs-on: ubuntu-latest  # Changed from: [self-hosted, arc, the1studio, org]
    timeout-minutes: 30
```

**Pros:**
- ✅ Unblocks publishing immediately
- ✅ No infrastructure maintenance
- ✅ Reliable and well-tested

**Cons:**
- ⚠️ GitHub Actions minutes consumption (free tier: 2000 min/month)
- ⚠️ Slower (no local caching)
- ⚠️ Public IP (may need registry allowlist)

**Decision Point:**
- If ARC fix takes > 2 hours → Use GitHub-hosted temporarily
- If ARC fix quick (< 1 hour) → Stick with self-hosted

---

## Phase 2: Fix Cloudflare Worker Dispatch Method

**Priority:** P1 - HIGH
**Time:** 1 hour
**Risk:** LOW (well-understood fix)

### Problem

Cloudflare Worker currently uses `workflow_dispatch`:

```javascript
// Line 188-202 in cloudflare-worker/src/index.js
const response = await fetch(
  'https://api.github.com/repos/The1Studio/UPMAutoPublisher/actions/workflows/handle-publish-request.yml/dispatches',
  {
    body: JSON.stringify({
      ref: 'master',
      inputs: workflowInputs  // ❌ This is workflow_dispatch format
    })
  }
);
```

**Issue:** GitHub API returns HTTP 422 "workflow does not have workflow_dispatch trigger"

### Root Cause

GitHub workflow cache/sync issue. Local file shows `workflow_dispatch` but GitHub doesn't recognize it.

### Solution: Use `repository_dispatch` Instead

**Why:**
- ✅ More reliable (no GitHub cache issues)
- ✅ Explicitly designed for external triggers
- ✅ Better event payload structure
- ✅ Already supported by handler workflow

### Implementation Steps

#### 2.1. Update Cloudflare Worker

```javascript
// Replace triggerPublishWorkflow() function
async function triggerPublishWorkflow(webhookData, githubPat) {
  const clientPayload = {
    repository: webhookData.repository.full_name,
    commit_sha: webhookData.after,
    commit_message: webhookData.head_commit?.message || 'No message',
    commit_author: webhookData.pusher?.name || webhookData.sender?.login || 'unknown',
    branch: webhookData.ref.replace('refs/heads/', ''),
    package_path: '' // Empty for auto-detection
  };

  const response = await fetch(
    'https://api.github.com/repos/The1Studio/UPMAutoPublisher/dispatches',  // ✅ Repository-level endpoint
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${githubPat}`,
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'UPMAutoPublisher-Webhook/1.0',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        event_type: 'package_publish',  // ✅ Matches workflow trigger
        client_payload: clientPayload   // ✅ Correct payload structure
      })
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to trigger workflow: ${response.status} - ${errorText}`);
  }

  return {
    status: response.status,
    dispatched: true
  };
}
```

#### 2.2. Verify Workflow Supports `repository_dispatch`

```yaml
# In .github/workflows/handle-publish-request.yml (lines 3-5)
on:
  repository_dispatch:
    types: [package_publish]  # ✅ Already configured
  workflow_dispatch:          # Keep for manual testing
```

**Status:** ✅ Already supports both triggers

#### 2.3. Deploy Worker Update

```bash
cd cloudflare-worker

# Update src/index.js with new code
vim src/index.js

# Test locally (optional)
npm run dev

# Deploy
npm run deploy

# Verify deployment
wrangler deployments list
```

#### 2.4. Test Repository Dispatch

```bash
# Manual test using gh CLI
gh api /repos/The1Studio/UPMAutoPublisher/dispatches \
  -X POST \
  -f event_type='package_publish' \
  -f client_payload='{"repository":"The1Studio/TheOneFeature","commit_sha":"HEAD","commit_message":"test","commit_author":"test","branch":"master","package_path":""}'

# Check workflow run started
gh run list --workflow handle-publish-request.yml --limit 1

# Watch run
gh run watch
```

**Success Criteria:**
- ✅ API returns 204 No Content
- ✅ Workflow run appears in Actions tab
- ✅ Run executes successfully (after ARC fix)

---

## Phase 3: Remove Per-Repo Dispatcher Workflows

**Priority:** P2 - MEDIUM
**Time:** 2-4 hours
**Risk:** LOW (can be done gradually)

### Current State

Per-repo dispatchers deployed to 21 active repositories:
- File: `.github/workflows/upm-publish-dispatcher.yml`
- Purpose: Detect package.json changes → dispatch to handler
- Status: REDUNDANT (Cloudflare webhook does the same)

### Strategy: Gradual Removal

**Phases:**
1. Pilot (2 repos) - Validate webhook works without dispatcher
2. Batch 1 (5 repos) - Remove from low-traffic repos
3. Batch 2 (14 repos) - Remove from remaining repos
4. Cleanup - Update documentation, registry

### Pre-Removal Validation

**Before removing ANY dispatcher, verify:**

```bash
# 1. Repository is registered
jq -r '.repositories[] | select(.url | contains("RepoName")) | .status' config/repositories.json
# Expected: "active"

# 2. Webhook receives events from repo
cd cloudflare-worker
npm run tail | grep "RepoName"
# Expected: Log entries when pushing to RepoName

# 3. Handler workflow triggered by webhook
gh run list --workflow handle-publish-request.yml --limit 20 | grep "RepoName"
# Expected: Recent runs for RepoName
```

### Removal Process (Per Repository)

#### 3.1. Remove Dispatcher Workflow File

```bash
# Clone repository
gh repo clone The1Studio/RepoName
cd RepoName

# Create removal branch
git checkout -b chore/remove-dispatcher-workflow

# Remove dispatcher file
rm -f .github/workflows/upm-publish-dispatcher.yml

# Commit
git add .github/workflows/upm-publish-dispatcher.yml
git commit -m "chore: remove dispatcher workflow (using webhook-only architecture)

The UPM Auto Publisher now uses organization-level webhook for instant
publishing. Per-repository dispatcher workflows are no longer needed.

- Webhook receives push events directly
- Triggers publishing via repository_dispatch
- Zero repository-specific configuration required

See: UPMAutoPublisher docs/webhook-setup-guide.md"

# Push
git push origin chore/remove-dispatcher-workflow

# Create PR
gh pr create \
  --title "chore: remove dispatcher workflow (using webhook-only architecture)" \
  --body "## 🧹 Cleanup

This PR removes the per-repository dispatcher workflow as part of the transition to webhook-only architecture.

### What Changed
- ❌ Removed \`.github/workflows/upm-publish-dispatcher.yml\`

### Why
- ✅ Organization webhook now handles ALL publishing events
- ✅ No per-repo setup required (just register once)
- ✅ Instant event-driven publishing (<1s latency)
- ✅ Easier maintenance (update webhook once, not 24 repos)

### Impact
- **No functionality change** - Publishing continues to work
- Webhook has been handling events since 2025-11-12
- This PR just removes redundant code

### Testing
- [x] Repository is registered in UPMAutoPublisher
- [x] Webhook receives events from this repository
- [x] Publishing works without dispatcher (verified)

---

**Documentation:** [Webhook Setup Guide](https://github.com/The1Studio/UPMAutoPublisher/blob/master/docs/webhook-setup-guide.md)" \
  --label "cleanup" \
  --label "infrastructure"

# Enable auto-merge
gh pr merge --auto --squash
```

#### 3.2. Update Repository Registry

```bash
cd /mnt/Work/1M/1.OneTools/UPM/The1Studio/UPMAutoPublisher

# Add note to registry (optional)
jq '.repositories |= map(
  if .url | contains("RepoName")
  then . + {note: "Dispatcher removed 2025-11-14 (webhook-only)"}
  else .
  end
)' config/repositories.json > config/repositories.json.tmp
mv config/repositories.json.tmp config/repositories.json

git add config/repositories.json
git commit -m "docs: note dispatcher removal for RepoName"
git push
```

### Removal Schedule

**Week 1: Pilot (2 repos)**
- UnityBuildScript
- TheOne.ProjectSetup
- **Goal:** Verify webhook-only works perfectly
- **Monitoring:** 48 hours before proceeding

**Week 2: Batch 1 (5 repos)**
- TheOneFeature
- UITemplate
- GameFoundation
- LiveOps
- TheOne.FTUE

**Week 3: Batch 2 (14 remaining active repos)**
- All other active repositories

**Rollback Plan:**
If webhook fails:
1. Redeploy dispatcher to affected repos (saved in git history)
2. Debug webhook issue
3. Resume removal after fix

### Automation Script

```bash
#!/bin/bash
# remove-dispatcher.sh - Automate dispatcher removal

REPO=$1

if [ -z "$REPO" ]; then
  echo "Usage: ./remove-dispatcher.sh <repo-name>"
  exit 1
fi

echo "🗑️  Removing dispatcher from $REPO..."

# Clone
gh repo clone The1Studio/$REPO temp-$REPO
cd temp-$REPO

# Create branch
git checkout -b chore/remove-dispatcher-workflow

# Remove file
rm -f .github/workflows/upm-publish-dispatcher.yml

# Commit & push
git add .github/workflows/upm-publish-dispatcher.yml
git commit -m "chore: remove dispatcher workflow (webhook-only architecture)"
git push origin chore/remove-dispatcher-workflow

# Create PR with auto-merge
gh pr create --fill --label "cleanup" --label "infrastructure"
gh pr merge --auto --squash

# Cleanup
cd ..
rm -rf temp-$REPO

echo "✅ Done! PR created and auto-merge enabled"
```

---

## Phase 4: Update Documentation

**Priority:** P2 - MEDIUM
**Time:** 1-2 hours
**Risk:** LOW

### Documentation Updates Required

#### 4.1. README.md

**Remove:**
- ❌ References to "dispatcher-based architecture"
- ❌ Sections about `upm-publish-dispatcher.yml`
- ❌ Instructions to add dispatcher to repos

**Add:**
- ✅ Prominent webhook-only architecture section
- ✅ Link to webhook setup guide
- ✅ Simplified registration process (just add to JSON)

**Changes:**
```markdown
## 🆕 How It Works (Webhook-Only Architecture)

1. **Register Once**: Add repository to `config/repositories.json`
2. **Push Changes**: Update `package.json` version and push to master/main
3. **Instant Publishing**: Organization webhook automatically:
   - Detects `package.json` changes (<1 second)
   - Validates repository is registered
   - Triggers publishing workflow via repository_dispatch
   - Publishes to `upm.the1studio.org` if new version
   - Sends Discord notification

**No per-repository setup needed!** 🎉

### Architecture

```
Your Repository (push)
    ↓
GitHub Organization Webhook (instant)
    ↓
Cloudflare Worker (validates & dispatches)
    ↓
handle-publish-request.yml (publishes)
    ↓
Discord Notification ✅
```
```

#### 4.2. docs/setup-instructions.md

**Mark as DEPRECATED:**
```markdown
# Setup Instructions (DEPRECATED)

⚠️ **This guide is DEPRECATED as of 2025-11-14**

The system now uses webhook-only architecture. Per-repository setup is no longer needed.

**See instead:** [Webhook Setup Guide](webhook-setup-guide.md)

---

## Historical Reference (For Dispatcher Architecture)

The following instructions applied to the previous dispatcher-based architecture...
```

#### 4.3. docs/quick-registration.md

**Simplify registration steps:**
```markdown
# Quick Registration Guide

**Time:** 1 minute
**Architecture:** Webhook-only (no per-repo setup)

## Steps

### 1. Add to Registry (30 seconds)

Edit `config/repositories.json`:
```json
{
  "url": "https://github.com/The1Studio/YourRepo",
  "status": "active"
}
```

### 2. Commit & Push (15 seconds)

```bash
git add config/repositories.json
git commit -m "Register YourRepo for UPM auto-publishing"
git push origin master
```

### 3. Done! 🎉

No PR, no dispatcher workflow, no waiting.

**That's it!** Push a version change and it auto-publishes.
```

#### 4.4. CLAUDE.md

**Update architecture section:**
```markdown
## How It Works

### Webhook-Only Architecture

**Components:**
- **GitHub Organization Webhook** - Receives ALL push events instantly
- **Cloudflare Worker** - Validates & routes events (serverless, free)
- **handle-publish-request.yml** - Central handler in UPMAutoPublisher
- **Discord Notifications** - Success/failure alerts

**Flow:**
1. Developer pushes package.json change to any registered repo
2. GitHub webhook fires instantly (<1s) to Cloudflare Worker
3. Worker validates:
   - Repository is registered
   - Package.json changed
   - Status is "active"
4. Worker triggers `repository_dispatch` to UPMAutoPublisher
5. Handler clones repo, publishes packages, sends notifications

**Key Benefits:**
- ✅ Zero per-repo setup (just register once)
- ✅ Instant (<1s latency)
- ✅ Update logic once (no PR to 24 repos)
- ✅ Free (Cloudflare Workers free tier)
```

#### 4.5. docs/codebase-summary.md

**Update workflow section:**
```markdown
## Workflows (Core)

### `handle-publish-request.yml` (693 lines) 🎯 **CENTRAL HANDLER**
**Trigger:** `repository_dispatch` event type `package_publish` (from webhook)
**Purpose:** Centralized publishing logic for ALL repositories
**Called By:** Cloudflare Worker webhook handler

[... rest of description ...]

### ~~`upm-publish-dispatcher.yml`~~ (DEPRECATED)
**Status:** Removed as of 2025-11-14 (webhook-only architecture)
**Historical:** Lightweight dispatcher that ran in each repo (129 lines)
**Replaced By:** Organization webhook + Cloudflare Worker
```

---

## Phase 5: System Testing & Validation

**Priority:** P1 - HIGH
**Time:** 2-3 hours
**Risk:** MEDIUM (final validation)

### Test Matrix

#### Test 1: New Version Publish (Happy Path)

```bash
# Pick a test repository
cd TheOneFeature

# Bump version
cd Assets/Core
npm version patch
# Updates package.json: 1.2.10 → 1.2.11

# Commit & push
git add package.json
git commit -m "test: bump version for webhook validation"
git push origin master

# Watch Cloudflare Worker logs
cd ../../UPMAutoPublisher/cloudflare-worker
npm run tail
# Expected: "✅ Publish workflow triggered successfully"

# Watch workflow run
gh run watch --repo The1Studio/UPMAutoPublisher

# Verify package published
npm view @the1.packages/core@1.2.11 --registry https://upm.the1studio.org/
# Expected: Version details

# Check Discord notification
# Expected: Success embed with changelog
```

**Success Criteria:**
- ✅ Webhook received event (<1s)
- ✅ Worker validated and dispatched
- ✅ Workflow ran successfully
- ✅ Package published to registry
- ✅ Changelog generated
- ✅ Discord notification sent
- ✅ Total time: <5 minutes

#### Test 2: Multi-Package Repository

```bash
# Repository with 2+ packages
cd UITemplate

# Bump both packages
cd Assets/Core
npm version patch
cd ../Components
npm version patch
cd ../..

# Commit & push
git add Assets/*/package.json
git commit -m "test: bump multiple package versions"
git push origin master

# Verify both packages published
npm view @the1.packages/uitemplatecore --registry https://upm.the1studio.org/
npm view @the1.packages/uitemplatecomponents --registry https://upm.the1studio.org/
```

**Success Criteria:**
- ✅ Both packages detected
- ✅ Both packages published
- ✅ Both changelogs generated

#### Test 3: Already Published Version (Skip Path)

```bash
# Don't change version, just commit
cd TheOneFeature/Assets/Core
git commit --allow-empty -m "test: trigger without version change"
git push origin master

# Check workflow
gh run view --log
# Expected: "⏭️ Version already published, skipping..."
```

**Success Criteria:**
- ✅ Webhook received event
- ✅ Workflow ran
- ✅ Package skipped (not re-published)

#### Test 4: Unregistered Repository

```bash
# Repository NOT in config/repositories.json
cd SomeOtherRepo
git commit --allow-empty -m "test"
git push

# Check worker logs
cd UPMAutoPublisher/cloudflare-worker
npm run tail
# Expected: "⏭️ Repository not registered or not active"

# Verify no workflow run
gh run list --repo The1Studio/UPMAutoPublisher --limit 1
# Expected: No new run for this repo
```

**Success Criteria:**
- ✅ Webhook received event
- ✅ Worker filtered repo (not registered)
- ✅ No workflow triggered

#### Test 5: Disabled Repository

```bash
# Change status to "disabled"
jq '.repositories |= map(
  if .url | contains("TheOneFeature")
  then .status = "disabled"
  else .
  end
)' config/repositories.json > config/repositories.json.tmp
mv config/repositories.json.tmp config/repositories.json

# Push change
git add config/repositories.json
git commit -m "test: disable TheOneFeature"
git push

# Wait for worker to fetch updated config (cache: ~1 min)
sleep 60

# Try to publish
cd TheOneFeature/Assets/Core
npm version patch
git add package.json
git commit -m "test: should be skipped (disabled)"
git push

# Check worker logs
cd ../../UPMAutoPublisher/cloudflare-worker
npm run tail
# Expected: "⏭️ Repository not active"

# Re-enable
jq '.repositories |= map(
  if .url | contains("TheOneFeature")
  then .status = "active"
  else .
  end
)' config/repositories.json > config/repositories.json.tmp
mv config/repositories.json.tmp config/repositories.json
git add config/repositories.json
git commit -m "test: re-enable TheOneFeature"
git push
```

**Success Criteria:**
- ✅ Disabled repo skipped by webhook
- ✅ Re-enabled repo works again

#### Test 6: Error Handling

```bash
# Trigger with invalid package.json
cd TheOneFeature/Assets/Core
echo '{"name":"invalid",}' > package.json  # Invalid JSON
git add package.json
git commit -m "test: invalid JSON"
git push

# Check workflow
gh run view --log
# Expected: Validation error, graceful failure

# Fix
git checkout package.json
git add package.json
git commit -m "fix: restore valid package.json"
git push
```

**Success Criteria:**
- ✅ Workflow doesn't crash
- ✅ Error logged clearly
- ✅ Discord notification sent (failure)

### Load Testing

```bash
# Simulate burst of pushes (10 repos simultaneously)
for repo in UnityBuildScript TheOneFeature UITemplate GameFoundation LiveOps TheOne.FTUE ThirdPartyServices UITemplateProjectMigration UITemplateLocalization UITemplateLocalData; do
  (
    cd $repo
    git commit --allow-empty -m "test: load test"
    git push
  ) &
done
wait

# Check webhook handled all events
cd cloudflare-worker
npm run tail | grep "Publish triggered"
# Expected: 10 entries

# Check workflow queuing
gh run list --repo The1Studio/UPMAutoPublisher --limit 20
# Expected: 10 runs (may be queued if runners limited)
```

**Success Criteria:**
- ✅ All 10 events received
- ✅ All 10 workflows triggered
- ✅ No lost events
- ✅ All complete within 30 minutes

---

## Phase 6: Monitoring & Rollback Plan

**Priority:** P1 - HIGH
**Time:** Ongoing
**Risk:** LOW (insurance)

### Monitoring Setup

#### Webhook Health Dashboard

```bash
# Create monitoring script: monitor-webhook.sh
#!/bin/bash

echo "🔍 Webhook Health Check"
echo "======================="

# 1. Check webhook exists and is active
HOOK_ID=$(gh api /orgs/The1Studio/hooks --jq '.[] | select(.config.url | contains("upm-webhook")) | .id')

if [ -z "$HOOK_ID" ]; then
  echo "❌ Webhook not found"
  exit 1
fi

echo "✅ Webhook ID: $HOOK_ID"

# 2. Check recent deliveries
echo ""
echo "📊 Recent Deliveries (last 10):"
gh api "/orgs/The1Studio/hooks/$HOOK_ID/deliveries" --jq '.[] | {
  status: .status_code,
  repo: .request.payload.repository.full_name,
  time: .delivered_at
}' | head -10

# 3. Check failure rate
TOTAL=$(gh api "/orgs/The1Studio/hooks/$HOOK_ID/deliveries" --jq 'length')
FAILED=$(gh api "/orgs/The1Studio/hooks/$HOOK_ID/deliveries" --jq '[.[] | select(.status_code != 200)] | length')
SUCCESS=$(($TOTAL - $FAILED))

echo ""
echo "📈 Success Rate:"
echo "   Total: $TOTAL"
echo "   Success: $SUCCESS"
echo "   Failed: $FAILED"
echo "   Rate: $(( SUCCESS * 100 / TOTAL ))%"

# 4. Check Cloudflare Worker metrics
echo ""
echo "☁️  Cloudflare Worker Metrics:"
cd cloudflare-worker
wrangler tail --format json --once | jq -r 'select(.outcome != null) | .outcome' | sort | uniq -c
```

Run daily:
```bash
crontab -e
# Add:
0 9 * * * cd /path/to/UPMAutoPublisher && ./monitor-webhook.sh | tee -a logs/webhook-health.log
```

#### Alert on Failures

```bash
# Create alert script: alert-webhook-failures.sh
#!/bin/bash

HOOK_ID=$(gh api /orgs/The1Studio/hooks --jq '.[] | select(.config.url | contains("upm-webhook")) | .id')

# Check last 20 deliveries
FAILED=$(gh api "/orgs/The1Studio/hooks/$HOOK_ID/deliveries" --jq '[.[] | select(.status_code != 200)] | length' | head -20)

if [ "$FAILED" -gt 5 ]; then
  # Send Discord alert
  curl -X POST "$DISCORD_WEBHOOK_UPM" \
    -H "Content-Type: application/json" \
    -d '{
      "embeds": [{
        "title": "⚠️ Webhook Health Alert",
        "description": "Multiple webhook failures detected in last 20 deliveries",
        "color": 16776960,
        "fields": [
          {"name": "Failed Deliveries", "value": "'"$FAILED"'/20", "inline": true}
        ]
      }]
    }'
fi
```

### Rollback Plan

**If webhook-only system fails:**

#### Emergency Rollback to Dispatcher Architecture

```bash
#!/bin/bash
# emergency-rollback.sh - Redeploy dispatchers to all active repos

REPOS=$(jq -r '.repositories[] | select(.status == "active") | .url | split("/") | .[4]' config/repositories.json)

for REPO in $REPOS; do
  echo "🔄 Redeploying dispatcher to $REPO..."

  # Clone repo
  gh repo clone The1Studio/$REPO temp-$REPO
  cd temp-$REPO

  # Create emergency branch
  git checkout -b emergency/restore-dispatcher

  # Copy dispatcher from UPMAutoPublisher
  mkdir -p .github/workflows
  cp ../../.github/workflows/upm-publish-dispatcher.yml .github/workflows/

  # Commit
  git add .github/workflows/upm-publish-dispatcher.yml
  git commit -m "emergency: restore dispatcher workflow

Temporary rollback to dispatcher architecture due to webhook issues.
This will be reverted once webhook is stable."

  # Push
  git push origin emergency/restore-dispatcher

  # Create PR (no auto-merge for emergency)
  gh pr create \
    --title "EMERGENCY: Restore dispatcher workflow" \
    --body "Temporary rollback due to webhook issues. Needs immediate merge." \
    --label "emergency" \
    --label "infrastructure"

  # Cleanup
  cd ..
  rm -rf temp-$REPO

  echo "✅ PR created for $REPO"
done

echo ""
echo "⚠️  EMERGENCY ROLLBACK COMPLETE"
echo "📝 Manual action required: Merge all PRs immediately"
```

**Rollback triggers:**
- Webhook failure rate > 25% for 1 hour
- Multiple repositories unable to publish
- Cloudflare Worker outage (unlikely)
- Critical bug in dispatch logic

---

## Risk Assessment

### Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| **ARC runners stay broken** | MEDIUM | HIGH | Fallback to GitHub-hosted runners (quick) |
| **Webhook dispatch fails** | LOW | HIGH | Rollback script ready, dispatchers in git history |
| **Worker deployment breaks** | LOW | MEDIUM | Wrangler rollback in <1 min |
| **Repository missed during removal** | LOW | LOW | Gradual rollback schedule, validation per repo |
| **Cache issues with config** | MEDIUM | LOW | Worker fetches config on every request (no cache) |
| **GitHub API rate limits** | LOW | MEDIUM | Worker uses organization PAT (5000 req/hr limit) |

### Pre-Flight Checklist

Before starting Phase 1:
- [ ] Backup current ARC configuration (`kubectl get -n arc-runners -o yaml > backup.yaml`)
- [ ] Document current runner state (screenshots, logs)
- [ ] Verify GH_PAT has correct scopes
- [ ] Test GitHub-hosted fallback works
- [ ] Inform team of maintenance window

Before starting Phase 3 (dispatcher removal):
- [ ] Phase 1 complete (runners working)
- [ ] Phase 2 complete (webhook tested)
- [ ] 48+ hours of stable webhook operation
- [ ] Pilot repos tested successfully
- [ ] Rollback script tested on one repo

---

## Success Metrics

### Technical Metrics

- ✅ **ARC Runners:** 100% job pickup rate
- ✅ **Webhook Success Rate:** >99% (GitHub SLA)
- ✅ **Publish Latency:** <10 seconds webhook → workflow start
- ✅ **Total Publish Time:** <5 minutes (unchanged from dispatcher)
- ✅ **Dispatcher Removal:** 100% of active repos (21/21)

### Operational Metrics

- ✅ **Maintenance Burden:** 90% reduction (1 workflow vs 21 files)
- ✅ **Registration Time:** 1 minute (down from 5-10 minutes)
- ✅ **Zero Per-Repo Setup:** No PR needed in target repos
- ✅ **Documentation:** All guides updated, dispatcher marked deprecated

---

## Timeline

### Optimistic (8 hours)

- **Phase 1:** 1 hour (ARC easy fix)
- **Phase 2:** 1 hour (worker update)
- **Phase 3:** 3 hours (pilot + batch removal)
- **Phase 4:** 1 hour (docs)
- **Phase 5:** 2 hours (testing)

### Realistic (12 hours)

- **Phase 1:** 2 hours (ARC debugging required)
- **Phase 2:** 1 hour
- **Phase 3:** 4 hours (gradual rollout with monitoring)
- **Phase 4:** 2 hours (comprehensive docs)
- **Phase 5:** 3 hours (thorough testing)

### Pessimistic (16 hours)

- **Phase 1:** 4 hours (ARC complex issues, fallback to GitHub-hosted)
- **Phase 2:** 1 hour
- **Phase 3:** 6 hours (careful gradual rollout, issues found)
- **Phase 4:** 2 hours
- **Phase 5:** 3 hours

---

## Next Steps

1. **Immediate:** Investigate ARC runner failure (kubectl diagnostics)
2. **Day 1:** Fix ARC or fallback to GitHub-hosted
3. **Day 1:** Update Cloudflare Worker to repository_dispatch
4. **Day 2-3:** Test webhook thoroughly (all test scenarios)
5. **Week 1:** Remove dispatchers from pilot repos (2)
6. **Week 2:** Remove dispatchers from batch 1 (5 repos)
7. **Week 3:** Remove dispatchers from batch 2 (14 repos)
8. **Week 4:** Update all documentation, announce completion

---

## Unresolved Questions

1. **ARC Runner Root Cause:** Need kubectl access to diagnose. Is it authentication, networking, or configuration?
2. **GitHub-Hosted Runner Allowlist:** Does `upm.the1studio.org` need to allowlist GitHub runner IPs?
3. **Cloudflare Worker URL:** Is current worker deployed? What's the URL? Need to verify webhook configuration.
4. **Dispatcher Removal Timeline:** Should we wait 1 week or proceed faster if webhook proven stable?
5. **Rollback Testing:** Should we test rollback script on one repo before emergency situation?

---

**End of Plan**
