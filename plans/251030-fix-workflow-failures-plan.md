# Implementation Plan: Fix GitHub Actions Workflow Failures

**Date:** 2025-10-30
**Project:** UPMAutoPublisher
**Status:** Ready for Implementation

---

## Overview

Multiple GitHub Actions workflows are failing across UPMAutoPublisher project. Analysis of recent failures reveals 3 distinct root causes:

1. **Workflow file syntax error** - Steps out of order in `publish-upm.yml`
2. **GitHub authentication failure** - Missing GH_TOKEN in cache rebuild step
3. **Self-hosted runner availability** - Monitor workflow couldn't acquire runner

---

## Root Cause Analysis

### Issue 1: Workflow File Syntax Error (CRITICAL)
**Workflow:** `.github/workflows/publish-upm.yml`
**Runs Affected:** 18933128022, 18931154652

**Problem:**
```yaml
steps:
  - name: Checkout repository

  - name: Install dependencies   # Lines 33-44
    run: |
      sudo sed -i 's|http://...  # APT fixes, jq install
    uses: actions/checkout@v5    # Line 45 - WRONG ORDER!
```

Steps are malformed - `Install dependencies` has both `run:` and `uses:` blocks, with `uses: actions/checkout` appearing AFTER the run command instead of being its own step.

**Impact:** HIGH - Workflow file cannot parse, prevents all package publishes
**Evidence:** "This run likely failed because of a workflow file issue"

---

### Issue 2: GitHub Authentication Missing
**Workflow:** `.github/workflows/publish-unpublished.yml`
**Run:** 18932602435
**Step:** "Rebuild package cache"

**Error:**
```
❌ Error: Not authenticated with GitHub
Run: gh auth login
##[error]Process completed with exit code 1.
```

**Root Cause:**
`build-package-cache.sh` (line 45) checks `gh auth status` but workflow step doesn't set `GH_TOKEN` environment variable:

```yaml
- name: Rebuild package cache
  if: success() && (inputs.dry_run == 'false' || github.event_name == 'schedule')
  env:
    GH_TOKEN: ${{ secrets.GH_PAT }}  # ✅ HAS THIS
  run: |
    ./scripts/build-package-cache.sh  # ✅ WORKS

# BUT in publish-unpublished.yml line 285-295:
- name: Rebuild package cache
  # env: section MISSING!  # ❌ NO GH_TOKEN SET
  run: |
    ./scripts/build-package-cache.sh  # ❌ FAILS - no auth
```

**Impact:** MEDIUM - Batch publish succeeds but cache not updated, causing stale data

---

### Issue 3: Self-Hosted Runner Unavailability
**Workflow:** `.github/workflows/monitor-publishes.yml`
**Runs:** 18930235619, 18929330246

**Error:**
```
The job was not acquired by Runner of type self-hosted even after multiple attempts
```

**Root Cause:**
All workflows use `runs-on: [self-hosted, arc, the1studio, org]` but runners may be:
- Offline/unreachable
- At capacity (max concurrent jobs)
- Network issues preventing job acquisition
- Kubernetes pod not scaling fast enough

**Impact:** LOW - Monitoring workflow only, not critical path. Recent runs show SUCCESS after fixing.

**Status:** ✅ RESOLVED - Recent 10 runs all successful, suggests transient issue

---

## Common Patterns Across Failures

1. **Syntax errors prevent workflow parsing** - publish-upm.yml malformed
2. **Missing environment variables** - GH_TOKEN not propagated to nested scripts
3. **Infrastructure transient failures** - Self-hosted runners occasionally unavailable
4. **Error handling gaps** - Scripts fail without retry or graceful degradation

---

## Implementation Approach 1: Quick Fix (Minimal Changes)

### Description
Fix immediate blockers with minimal code changes. Focus on restoring functionality quickly.

### Pros
- ✅ Fast to implement (< 30 min)
- ✅ Low risk - only fixes obvious errors
- ✅ Unblocks package publishing immediately
- ✅ Easy to test and verify

### Cons
- ❌ Doesn't address root architectural issues
- ❌ No improvements to error handling
- ❌ May miss edge cases
- ❌ Requires follow-up work for robustness

### Implementation Steps

#### 1. Fix publish-upm.yml Syntax Error (CRITICAL)
**File:** `.github/workflows/publish-upm.yml`

**Change:**
```yaml
# BEFORE (lines 30-48):
steps:
  - name: Checkout repository

  - name: Install dependencies
    run: |
      sudo sed -i 's|http://archive.ubuntu.com|https://...'
      # ... more apt commands
      sudo apt-get install -y -qq jq
    uses: actions/checkout@v5
    with:
      fetch-depth: 2

# AFTER:
steps:
  - name: Checkout repository
    uses: actions/checkout@v5
    with:
      fetch-depth: 2

  - name: Install dependencies
    run: |
      sudo sed -i 's|http://archive.ubuntu.com|https://...'
      # ... more apt commands
      sudo apt-get install -y -qq jq
```

**Validation:**
```bash
# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/publish-upm.yml'))"

# Check workflow syntax with GitHub CLI
gh workflow view publish-upm.yml
```

---

#### 2. Add GH_TOKEN to Cache Rebuild Step
**File:** `.github/workflows/publish-unpublished.yml`

**Change:**
```yaml
# Line 285-295 - ADD env section:
- name: Rebuild package cache
  if: success() && (inputs.dry_run == 'false' || github.event_name == 'schedule')
  env:
    GH_TOKEN: ${{ secrets.GH_PAT }}  # ✅ ADD THIS
  run: |
    echo "REBUILD: Rebuilding package cache after publishing..."
    if [ -x "./scripts/build-package-cache.sh" ]; then
      ./scripts/build-package-cache.sh
    else
      echo "WARNING: build-package-cache.sh not found or not executable"
    fi
```

**Validation:**
```bash
# Test locally with real GH_TOKEN
export GH_TOKEN="ghp_YOUR_TOKEN"
./scripts/build-package-cache.sh

# Verify gh auth works
gh auth status
```

---

#### 3. Document Runner Issues (No Code Change)
**File:** `docs/troubleshooting.md`

**Add section:**
```markdown
### Self-Hosted Runner Not Available

**Symptoms:**
- "The job was not acquired by Runner of type self-hosted even after multiple attempts"
- Workflow queued indefinitely

**Causes:**
1. All runners at capacity (max concurrent jobs reached)
2. Kubernetes pod failed to scale
3. Network connectivity issues
4. Runner pods in crash loop

**Solutions:**
1. Wait 5-10 minutes and re-run workflow
2. Check runner status: `kubectl get pods -n actions-runner-system`
3. Check runner logs: `kubectl logs -n actions-runner-system <pod-name>`
4. Fallback: Change `runs-on: ubuntu-latest` temporarily
5. Scale runners: `kubectl scale deployment/arc-runner-set --replicas=5`

**Prevention:**
- Set up autoscaling with higher max replicas
- Add workflow timeout: `timeout-minutes: 15`
- Configure queue timeout: `timeout-minutes: 10` at job level
```

---

### Testing Strategy

1. **Syntax Validation**
   ```bash
   # Validate all workflow files
   for f in .github/workflows/*.yml; do
     echo "Checking $f..."
     python3 -c "import yaml; yaml.safe_load(open('$f'))"
   done
   ```

2. **Workflow Trigger Test**
   ```bash
   # Manual trigger publish-upm workflow
   gh workflow run publish-upm.yml

   # Check status
   gh run watch
   ```

3. **Cache Rebuild Test**
   ```bash
   # Manual trigger batch publish (dry run)
   gh workflow run publish-unpublished.yml -f dry_run=true

   # Verify cache rebuild step has GH_TOKEN
   gh run view --log | grep "GH_TOKEN"
   ```

---

### Files to Modify

**Changes Required:**
1. `.github/workflows/publish-upm.yml` - Fix step order (lines 30-48)
2. `.github/workflows/publish-unpublished.yml` - Add GH_TOKEN env (line 285)
3. `docs/troubleshooting.md` - Add runner availability section

**No Changes:**
- `.github/workflows/monitor-publishes.yml` - Already working (10/10 recent runs pass)
- `scripts/build-package-cache.sh` - Works correctly when GH_TOKEN set

---

### Trade-offs

**Speed vs Robustness:**
- This approach prioritizes speed (fix now, improve later)
- Gets workflows running again within 1 hour
- Leaves architectural issues for future iteration

**Risk Level:** LOW
- Changes are minimal and localized
- Easy to revert if issues arise
- Comprehensive testing before merge

**Follow-up Required:**
- Implement Approach 2 improvements in next sprint
- Add comprehensive error handling
- Improve monitoring and alerting

---

## Implementation Approach 2: Robust Solution (Comprehensive Improvements)

### Description
Fix root causes AND improve error handling, retry logic, monitoring, and infrastructure resilience.

### Pros
- ✅ Addresses root architectural issues
- ✅ Prevents future similar failures
- ✅ Comprehensive error handling
- ✅ Better monitoring and observability
- ✅ More maintainable long-term

### Cons
- ❌ Takes longer to implement (4-8 hours)
- ❌ Higher complexity
- ❌ More testing required
- ❌ Requires infrastructure changes

### Implementation Steps

#### 1. Fix Syntax + Refactor Workflow Structure
**File:** `.github/workflows/publish-upm.yml`

**Improvements:**
- Fix step order (same as Approach 1)
- Add composite action for APT fixes (reusable)
- Add retry logic for npm operations
- Add fallback to GitHub-hosted runners

**Create:** `.github/actions/setup-self-hosted-env/action.yml`
```yaml
name: Setup Self-Hosted Environment
description: Fixes common self-hosted runner issues (APT HTTPS, dependencies)

runs:
  using: "composite"
  steps:
    - name: Fix APT sources
      shell: bash
      run: |
        sudo sed -i 's|http://archive.ubuntu.com|https://archive.ubuntu.com|g' /etc/apt/sources.list
        sudo sed -i 's|http://security.ubuntu.com|https://security.ubuntu.com|g' /etc/apt/sources.list

        sudo mv /etc/apt/sources.list.d /etc/apt/sources.list.d.bak 2>/dev/null || true
        sudo mkdir -p /etc/apt/sources.list.d

    - name: Install dependencies
      shell: bash
      run: |
        sudo apt-get update -qq
        sudo apt-get install -y -qq jq curl
```

**Update:** `.github/workflows/publish-upm.yml`
```yaml
jobs:
  publish:
    runs-on: [self-hosted, arc, the1studio, org]
    timeout-minutes: 20

    steps:
      - name: Checkout repository
        uses: actions/checkout@v5
        with:
          fetch-depth: 2

      - name: Setup environment
        uses: ./.github/actions/setup-self-hosted-env

      # ... rest of steps
```

---

#### 2. Add Comprehensive Error Handling
**File:** `scripts/build-package-cache.sh`

**Add retry logic:**
```bash
# Replace line 45-48 with:
check_gh_auth() {
  local max_attempts=3
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    if gh auth status &>/dev/null; then
      return 0
    fi

    if [ $attempt -lt $max_attempts ]; then
      echo "${WARN} GitHub auth check failed, attempt $attempt/$max_attempts"
      echo "   Checking GH_TOKEN environment variable..."

      if [ -z "${GH_TOKEN:-}" ]; then
        echo "${CROSS} GH_TOKEN not set"
        return 1
      fi

      echo "   GH_TOKEN is set, attempting auth refresh..."
      echo "$GH_TOKEN" | gh auth login --with-token 2>&1 || true
      sleep 2
      ((attempt++))
    else
      return 1
    fi
  done
}

if ! check_gh_auth; then
  echo "${CROSS} Error: Not authenticated with GitHub after $max_attempts attempts"
  echo "Troubleshooting:"
  echo "  1. Verify GH_PAT secret is set in organization secrets"
  echo "  2. Check if token has expired (90-day limit)"
  echo "  3. Ensure workflow has: env: GH_TOKEN: \${{ secrets.GH_PAT }}"
  exit 1
fi
```

---

#### 3. Add Workflow Fallback Strategy
**File:** `.github/workflows/publish-upm.yml`

**Add fallback job:**
```yaml
jobs:
  publish:
    runs-on: [self-hosted, arc, the1studio, org]
    timeout-minutes: 20
    continue-on-error: true  # Don't fail workflow if self-hosted unavailable
    outputs:
      success: ${{ steps.check_success.outputs.success }}

    steps:
      # ... existing steps

      - name: Check job success
        id: check_success
        if: always()
        run: |
          if [ "${{ job.status }}" = "success" ]; then
            echo "success=true" >> $GITHUB_OUTPUT
          else
            echo "success=false" >> $GITHUB_OUTPUT
          fi

  # Fallback to GitHub-hosted runner if self-hosted fails
  publish-fallback:
    runs-on: ubuntu-latest
    needs: publish
    if: needs.publish.outputs.success != 'true'
    timeout-minutes: 20

    steps:
      - name: Checkout repository
        uses: actions/checkout@v5
        with:
          fetch-depth: 2

      - name: Install dependencies
        run: |
          sudo apt-get update -qq
          sudo apt-get install -y -qq jq

      # ... rest of publish steps (same logic)

      - name: Notify fallback used
        run: |
          echo "⚠️  Self-hosted runner unavailable, used GitHub-hosted runner"
          echo "This may have cost implications (Actions minutes)"
```

---

#### 4. Enhanced Monitoring and Alerting
**File:** `.github/workflows/workflow-health-check.yml` (NEW)

```yaml
name: Workflow Health Check

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:

jobs:
  health-check:
    runs-on: ubuntu-latest
    steps:
      - name: Check workflow failure rate
        env:
          GH_TOKEN: ${{ secrets.GH_PAT }}
        run: |
          echo "🔍 Checking workflow health..."

          workflows=("publish-upm.yml" "publish-unpublished.yml" "monitor-publishes.yml")

          for workflow in "${workflows[@]}"; do
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Workflow: $workflow"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

            # Get last 20 runs
            runs=$(gh api "repos/${{ github.repository }}/actions/workflows/$workflow/runs?per_page=20" \
              --jq '.workflow_runs[] | "\(.conclusion)"')

            total=$(echo "$runs" | wc -l)
            failed=$(echo "$runs" | grep -c "failure" || echo 0)
            success=$(echo "$runs" | grep -c "success" || echo 0)

            failure_rate=$((failed * 100 / total))

            echo "Total runs: $total"
            echo "✅ Success: $success"
            echo "❌ Failed: $failed"
            echo "📊 Failure rate: ${failure_rate}%"

            if [ $failure_rate -gt 20 ]; then
              echo "⚠️  HIGH FAILURE RATE DETECTED!"
              echo "Action required: investigate $workflow"
            fi
          done

      - name: Check runner availability
        run: |
          echo ""
          echo "🏃 Checking self-hosted runner availability..."

          # Try to ping runner (simple job)
          echo "Testing runner acquisition time..."
          start_time=$(date +%s)

          # This would require actual runner test - simplified here
          echo "Runner health check would go here"
```

---

#### 5. Add Configuration Validation Script
**File:** `scripts/validate-workflows.sh` (NEW)

```bash
#!/usr/bin/env bash
# Validates all workflow files for common issues

set -euo pipefail

echo "🔍 Validating GitHub Actions workflows..."
echo ""

errors=0

# Check 1: YAML syntax
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. YAML Syntax Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for workflow in .github/workflows/*.yml; do
  echo "Checking $workflow..."

  if ! python3 -c "import yaml; yaml.safe_load(open('$workflow'))" 2>&1; then
    echo "❌ YAML syntax error in $workflow"
    ((errors++))
  else
    echo "✅ Valid YAML"
  fi
done

# Check 2: actions/checkout is first step
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Checkout Action Ordering"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for workflow in .github/workflows/*.yml; do
  echo "Checking $workflow..."

  # Extract first step that uses 'uses:'
  first_uses=$(python3 -c "
import yaml
with open('$workflow') as f:
  data = yaml.safe_load(f)
  for job in data.get('jobs', {}).values():
    steps = job.get('steps', [])
    for step in steps:
      if 'uses' in step:
        print(step['uses'])
        break
    break
" 2>/dev/null || echo "")

  if [[ "$first_uses" == actions/checkout* ]]; then
    echo "✅ Checkout is first action"
  elif [ -n "$first_uses" ]; then
    echo "⚠️  First action is: $first_uses (not checkout)"
  fi
done

# Check 3: Required secrets/vars
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Required Secrets and Variables"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

required_secrets=("NPM_TOKEN" "GH_PAT" "DISCORD_WEBHOOK")
required_vars=("UPM_REGISTRY")

echo "Required secrets: ${required_secrets[*]}"
echo "Required vars: ${required_vars[*]}"
echo ""
echo "⚠️  Cannot validate secrets/vars exist (requires GitHub API access)"
echo "   Ensure these are set in organization/repository settings"

# Check 4: Runner labels
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Self-Hosted Runner Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for workflow in .github/workflows/*.yml; do
  echo "Checking $workflow..."

  if grep -q "runs-on.*self-hosted" "$workflow"; then
    echo "✅ Uses self-hosted runners"

    if grep -q "timeout-minutes" "$workflow"; then
      echo "✅ Has timeout configured"
    else
      echo "⚠️  No timeout - consider adding for self-hosted runners"
    fi
  else
    echo "ℹ️  Uses GitHub-hosted runners"
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Validation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $errors -eq 0 ]; then
  echo "✅ All checks passed!"
  exit 0
else
  echo "❌ Found $errors error(s)"
  exit 1
fi
```

**Add to CI:**
```yaml
# .github/workflows/validate-workflows.yml
name: Validate Workflows

on:
  pull_request:
    paths:
      - '.github/workflows/**'
  push:
    branches: [master, main]
    paths:
      - '.github/workflows/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - name: Validate workflows
        run: ./scripts/validate-workflows.sh
```

---

### Testing Strategy

1. **Local Validation**
   ```bash
   # Validate all workflows
   ./scripts/validate-workflows.sh

   # Test cache rebuild with retry logic
   export GH_TOKEN="ghp_test"
   ./scripts/build-package-cache.sh
   ```

2. **Staging Environment Test**
   ```bash
   # Create test repository
   gh repo create The1Studio/UPMAutoPublisher-test --private

   # Copy workflows
   cp -r .github/workflows UPMAutoPublisher-test/.github/

   # Trigger test runs
   cd UPMAutoPublisher-test
   gh workflow run publish-upm.yml
   gh workflow run publish-unpublished.yml
   ```

3. **Failure Injection Testing**
   ```bash
   # Test without GH_TOKEN
   unset GH_TOKEN
   ./scripts/build-package-cache.sh  # Should fail gracefully with clear error

   # Test with invalid GH_TOKEN
   export GH_TOKEN="invalid"
   ./scripts/build-package-cache.sh  # Should retry and fail with clear message

   # Test runner unavailability
   # Manually scale runners to 0 and trigger workflow
   kubectl scale deployment/arc-runner-set --replicas=0
   gh workflow run publish-upm.yml
   # Should fallback to GitHub-hosted runner
   ```

4. **Health Check Validation**
   ```bash
   # Run health check manually
   gh workflow run workflow-health-check.yml

   # Check outputs
   gh run view --log
   ```

---

### Files to Modify/Create

**Modifications:**
1. `.github/workflows/publish-upm.yml` - Fix syntax + add fallback (150 lines)
2. `.github/workflows/publish-unpublished.yml` - Add GH_TOKEN + retry (20 lines)
3. `scripts/build-package-cache.sh` - Enhanced error handling (40 lines)
4. `docs/troubleshooting.md` - Add comprehensive guide (100 lines)

**New Files:**
1. `.github/actions/setup-self-hosted-env/action.yml` - Reusable setup (30 lines)
2. `.github/workflows/workflow-health-check.yml` - Monitoring (80 lines)
3. `.github/workflows/validate-workflows.yml` - Pre-commit validation (20 lines)
4. `scripts/validate-workflows.sh` - Validation script (150 lines)

**Total Changes:** ~590 lines across 8 files

---

### Trade-offs

**Robustness vs Complexity:**
- More comprehensive but requires more testing
- Higher initial investment (4-8 hours) but lower maintenance long-term
- More moving parts to understand and maintain

**Cost Considerations:**
- Fallback to GitHub-hosted runners consumes Actions minutes
- Health check workflow runs every 6 hours (minimal cost)
- Trade-off: Reliability vs GitHub Actions usage costs

**Risk Level:** MEDIUM
- More changes = more surface area for bugs
- Requires thorough testing before production
- Benefits outweigh risks for long-term stability

---

## Recommended Approach

### Two-Phase Implementation: Quick Fix First, Then Improve

**Rationale:**
1. **Phase 1 (NOW):** Implement Approach 1 - Quick Fix
   - Unblocks package publishing within 1 hour
   - Low risk, minimal changes
   - Gets workflows green immediately
   - Provides breathing room for Phase 2

2. **Phase 2 (NEXT SPRINT):** Implement Approach 2 - Comprehensive Improvements
   - Build on working foundation
   - Add robustness and monitoring
   - Time to properly test and validate
   - Can be done iteratively

**Why This Hybrid Approach?**
- ✅ **Immediate value** - Fixes critical blockers now
- ✅ **Risk mitigation** - Two small deployments vs one big bang
- ✅ **Learning opportunity** - Phase 1 reveals edge cases for Phase 2
- ✅ **Stakeholder satisfaction** - Shows quick progress + long-term planning
- ✅ **Testing time** - Phase 2 can be tested thoroughly in parallel

**Timeline:**
- **Phase 1:** 1-2 hours (implement + test + deploy)
- **Phase 2:** 1-2 weeks (implement + test + monitor + iterate)

---

## Security Considerations

### Secrets Management
- ✅ `NPM_TOKEN` already stored as organization secret
- ✅ `GH_PAT` already stored as organization secret
- ⚠️  Ensure `GH_PAT` has minimal required scopes: `repo`, `workflow`
- ⚠️  Rotate `GH_PAT` every 90 days (set calendar reminder)

### Runner Security
- ✅ Self-hosted runners isolated in Kubernetes namespace
- ✅ APT HTTPS fixes prevent MITM attacks
- ⚠️  Fallback to GitHub-hosted runners exposes code to shared runners
- ⚠️  Consider private networking for GitHub-hosted if using fallback

### Code Injection Prevention
- ✅ All workflows use explicit versions (e.g., `@v5`)
- ✅ No dynamic evaluation of user input
- ✅ Secrets not exposed in logs

---

## Performance Considerations

### Workflow Execution Time
- **Current:** 5-10 minutes per publish (when working)
- **After Phase 1:** Same (just fixes errors)
- **After Phase 2:** 7-12 minutes (retry logic adds overhead)

### Resource Usage
- **Self-hosted runners:** Minimal change
- **GitHub-hosted fallback:** Only used on failure (rare)
- **Health checks:** Runs every 6 hours, ~2 minutes each

### Optimization Opportunities
- Cache npm packages to reduce `npm view` calls
- Parallel package processing (currently sequential)
- Use GitHub API v4 (GraphQL) for batch queries

---

## Risks & Mitigations

### Risk 1: Fallback Runner Cost Explosion
**Scenario:** Self-hosted runners permanently fail, all workflows use GitHub-hosted
**Impact:** HIGH - Could consume thousands of Actions minutes
**Mitigation:**
- Set up alerts for GitHub-hosted runner usage
- Add workflow run limit per day
- Monitor Actions usage in organization settings
- Fix self-hosted runners within 24 hours if fallback triggered

### Risk 2: GH_PAT Expiration
**Scenario:** `GH_PAT` expires, all workflows requiring GitHub API fail
**Impact:** HIGH - Batch publish and cache rebuild broken
**Mitigation:**
- Set calendar reminder for 30 days before expiration
- Add workflow to check PAT expiration date weekly
- Document rotation procedure in `docs/configuration.md`
- Store backup PAT from different user

### Risk 3: Kubernetes Runner Scaling Issues
**Scenario:** ARC auto-scaler fails, runners can't scale up
**Impact:** MEDIUM - Workflows queue indefinitely
**Mitigation:**
- Manual scale: `kubectl scale deployment/arc-runner-set --replicas=10`
- Set up external monitoring (Prometheus alerts)
- Document scaling procedures in ARC runbook
- Use workflow timeout to fail fast (not hang forever)

### Risk 4: NPM Registry Downtime
**Scenario:** `upm.the1studio.org` is down or unreachable
**Impact:** HIGH - Cannot publish packages
**Mitigation:**
- Health check step catches early (before attempting publish)
- Retry logic with exponential backoff
- Clear error messages for troubleshooting
- Consider backup registry (e.g., Cloudflare R2 + Verdaccio)

---

## Acceptance Criteria

### Phase 1 (Quick Fix)
- [ ] `publish-upm.yml` syntax validated, workflow runs without parsing errors
- [ ] Workflow successfully triggered manually via `gh workflow run`
- [ ] Package published successfully (test with dummy version bump)
- [ ] Cache rebuild step completes without authentication errors
- [ ] All 3 workflows (publish, batch, monitor) pass at least once
- [ ] No new errors introduced by changes

### Phase 2 (Comprehensive)
- [ ] Fallback runner tested (manually disable self-hosted, verify GitHub-hosted used)
- [ ] Retry logic tested (inject GH_TOKEN failure, verify 3 retries happen)
- [ ] Health check workflow runs successfully every 6 hours
- [ ] Validation script passes for all workflows
- [ ] Documentation updated with troubleshooting guides
- [ ] Zero workflow failures for 7 consecutive days

---

## Rollback Plan

### If Phase 1 Breaks Workflows
```bash
# Revert commits
git revert HEAD~2..HEAD  # Assuming 2 commits for Phase 1

# Or restore from backup
git checkout origin/master -- .github/workflows/

# Re-run workflows
gh workflow run publish-upm.yml
```

### If Phase 2 Causes Issues
```bash
# Disable fallback runner (remove job)
git revert <phase2-commit-hash>

# Or feature flag approach:
# Add to workflow:
if: vars.ENABLE_FALLBACK_RUNNER == 'true'  # Default: not set = disabled

# To re-enable later:
gh variable set ENABLE_FALLBACK_RUNNER=true
```

---

## Post-Implementation Monitoring

### Week 1: Intensive Monitoring
- [ ] Check workflow status 3x per day
- [ ] Review all logs for warnings
- [ ] Monitor Actions minutes usage
- [ ] Check self-hosted runner resource usage

### Week 2-4: Normal Monitoring
- [ ] Review weekly health check reports
- [ ] Check failure rate metrics
- [ ] Validate cache rebuild frequency
- [ ] Review any new error patterns

### Metrics to Track
1. **Workflow Success Rate:** Target >95%
2. **Average Execution Time:** Target <10 minutes
3. **Fallback Runner Usage:** Target <5% of runs
4. **Cache Freshness:** Updated within 24 hours of publishes
5. **GH_TOKEN Expiration:** >30 days until expiration

---

## Unresolved Questions

### Question 1: Should we implement circuit breaker pattern?
**Context:** If registry is down, stop attempting publishes for X minutes
**Impact:** Reduces unnecessary workflow runs and API calls
**Decision Needed:** Determine circuit breaker timeout (5 min? 15 min?)
**Who Decides:** Infrastructure team + DevOps

### Question 2: What's the acceptable failure rate for monitor workflow?
**Context:** Monitor runs every 15 minutes (96x per day)
**Impact:** Determines if we need more robust monitoring
**Decision Needed:** Is 5% failure rate acceptable? 1%?
**Who Decides:** Product/Ops team based on alert fatigue tolerance

### Question 3: Should we add package publish notifications to Discord?
**Context:** Currently only batch publish sends Discord notifications
**Impact:** More visibility but potential noise
**Decision Needed:** Per-package publish notifications useful?
**Who Decides:** Team using the packages (The1Studio devs)

### Question 4: Backup registry strategy?
**Context:** Single point of failure at `upm.the1studio.org`
**Impact:** If down, no publishes possible
**Decision Needed:** Set up backup Verdaccio instance?
**Who Decides:** Infrastructure team based on cost/benefit analysis

---

## TODO Checklist

### Immediate (Phase 1)
- [ ] Review this plan with team
- [ ] Get approval for Phase 1 changes
- [ ] Create feature branch: `fix/workflow-failures`
- [ ] Fix `publish-upm.yml` step order
- [ ] Add `GH_TOKEN` to cache rebuild step
- [ ] Validate all YAML files
- [ ] Test workflows locally/staging
- [ ] Create PR with detailed description
- [ ] Get PR reviewed and approved
- [ ] Merge to master
- [ ] Monitor workflows for 24 hours
- [ ] Document any issues found

### Next Sprint (Phase 2)
- [ ] Schedule Phase 2 planning meeting
- [ ] Create epic in project tracker
- [ ] Break down Phase 2 into smaller tasks
- [ ] Implement composite action for setup
- [ ] Add retry logic to cache rebuild
- [ ] Implement fallback runner strategy
- [ ] Create health check workflow
- [ ] Create validation script
- [ ] Update all documentation
- [ ] Create Phase 2 PR
- [ ] Comprehensive testing in staging
- [ ] Gradual rollout to production
- [ ] Monitor for 2 weeks
- [ ] Retrospective on both phases

---

## References

### Documentation
- [GitHub Actions Workflow Syntax](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions)
- [Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [ARC Documentation](https://github.com/actions/actions-runner-controller)

### Internal Documentation
- `docs/architecture-decisions.md` - Why workflows designed this way
- `docs/troubleshooting.md` - Common issues and solutions
- `docs/self-hosted-runners.md` - Runner setup and management
- `.github/workflows/publish-upm.yml` - Main publishing workflow

### Related Issues
- (None yet - this is initial analysis)

---

**Plan Status:** ✅ Ready for Implementation
**Estimated Implementation Time:** Phase 1: 1-2 hours, Phase 2: 8-16 hours
**Risk Level:** Phase 1: LOW, Phase 2: MEDIUM
**Priority:** CRITICAL (blocks package publishing)

**Next Step:** Review this plan with team and get approval to proceed with Phase 1.
