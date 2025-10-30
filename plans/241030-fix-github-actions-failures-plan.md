# GitHub Actions Workflow Failures Fix - Implementation Plan
**Date:** 2024-10-30
**Project:** UPMAutoPublisher
**Criticality:** HIGH - Publishing completely broken

## Executive Summary

Critical syntax error in main publishing workflow blocks ALL package publishing. Two additional issues in related workflows. All issues have clear fixes with minimal risk.

## Priority 1: Critical Fixes (Must Do NOW)

### 1.1 Fix Malformed Steps in publish-upm.yml

**Issue:** Lines 31-48 have invalid YAML structure - checkout action placed after run command
**Impact:** Workflow fails immediately, no packages can publish
**Location:** `.github/workflows/publish-upm.yml` lines 31-48

**Current (BROKEN):**
```yaml
steps:
  - name: Checkout repository

  - name: Install dependencies
    run: |
      # Fix APT sources...
    uses: actions/checkout@v5  # WRONG - This is INSIDE run block!
    with:
      fetch-depth: 2
```

**Fix Required:**
```yaml
steps:
  - name: Checkout repository
    uses: actions/checkout@v5
    with:
      fetch-depth: 2

  - name: Install dependencies
    run: |
      # Fix APT sources...
```

### 1.2 Add GH_TOKEN to Cache Rebuild

**Issue:** Line 288 in `publish-unpublished.yml` missing authentication
**Impact:** Cache rebuild fails after batch publishing
**Location:** `.github/workflows/publish-unpublished.yml` line 286-295

**Current:**
```yaml
- name: Rebuild package cache
  if: success() && (inputs.dry_run == 'false' || github.event_name == 'schedule')
  run: |
    # Missing GH_TOKEN env var!
    ./scripts/build-package-cache.sh
```

**Fix Required:**
```yaml
- name: Rebuild package cache
  if: success() && (inputs.dry_run == 'false' || github.event_name == 'schedule')
  env:
    GH_TOKEN: ${{ secrets.GH_PAT }}
  run: |
    ./scripts/build-package-cache.sh
```

## Priority 2: Robustness Improvements (Should Do Soon)

### 2.1 Add Fallback for Self-Hosted Runner Unavailability

**Current:** All workflows use `[self-hosted, arc, the1studio, org]`
**Risk:** If ARC runners down, nothing works

**Add to all workflows:**
```yaml
jobs:
  publish:
    runs-on: ${{ matrix.runner }}
    strategy:
      fail-fast: false
      matrix:
        runner:
          - [self-hosted, arc, the1studio, org]
          - ubuntu-latest  # Fallback
    continue-on-error: ${{ matrix.runner == 'ubuntu-latest' }}
```

### 2.2 Add Health Checks Before Critical Operations

**For publish-upm.yml - Add before line 112:**
```yaml
- name: Validate workflow environment
  run: |
    # Check critical environment variables
    if [ -z "${{ secrets.NPM_TOKEN }}" ]; then
      echo "ERROR: NPM_TOKEN secret not configured"
      exit 1
    fi

    if [ -z "${{ secrets.GH_PAT }}" ]; then
      echo "WARNING: GH_PAT not configured (may affect some operations)"
    fi

    # Verify npm registry accessibility
    if ! curl -f -s -m 10 "${{ vars.UPM_REGISTRY || 'https://upm.the1studio.org/' }}" >/dev/null 2>&1; then
      echo "ERROR: Registry not accessible"
      exit 1
    fi
```

### 2.3 Improve Error Messages and Debugging

**Add debug mode to all workflows:**
```yaml
env:
  ACTIONS_STEP_DEBUG: ${{ secrets.ACTIONS_STEP_DEBUG }}
  ACTIONS_RUNNER_DEBUG: ${{ secrets.ACTIONS_RUNNER_DEBUG }}
```

**Enhance error outputs in publish-upm.yml (line 463-510):**
```yaml
# Add more specific error detection
if echo "$publish_output" | grep -q "E401\|E403"; then
  echo "Authentication error - check NPM_TOKEN"
elif echo "$publish_output" | grep -q "E404"; then
  echo "Registry not found - check UPM_REGISTRY"
elif echo "$publish_output" | grep -q "ECONNREFUSED\|ETIMEDOUT"; then
  echo "Network error - registry may be down"
fi
```

## Priority 3: Optional Enhancements (Nice to Have)

### 3.1 Add Workflow Status Badges
- Create status badge endpoint
- Add to README.md
- Monitor workflow health visually

### 3.2 Implement Notification Webhooks
- Add Slack notifications for failures
- Email alerts for critical failures
- Success summaries weekly

### 3.3 Add Telemetry and Metrics
- Track publish success rates
- Monitor average publish times
- Alert on degradation

## Implementation Sequence

1. **Fix critical syntax error** (5 min)
   - Edit `.github/workflows/publish-upm.yml`
   - Move checkout action to correct position
   - Test YAML validity

2. **Add GH_TOKEN to cache rebuild** (2 min)
   - Edit `.github/workflows/publish-unpublished.yml`
   - Add env variable to rebuild step

3. **Test fixes locally** (10 min)
   ```bash
   # Validate YAML syntax
   yamllint .github/workflows/*.yml

   # Test with act (GitHub Actions local runner)
   act -W .github/workflows/publish-upm.yml -n
   ```

4. **Commit and push fixes** (5 min)
   ```bash
   git add .github/workflows/publish-upm.yml
   git add .github/workflows/publish-unpublished.yml
   git commit -m "fix: Critical workflow syntax errors blocking all publishing"
   git push
   ```

5. **Trigger test publish** (10 min)
   - Use workflow_dispatch on a test package
   - Monitor Actions tab for success
   - Verify package appears in registry

6. **Apply robustness improvements** (30 min)
   - Add health checks
   - Implement runner fallbacks
   - Enhance error messages

## Testing Strategy

### Immediate Tests (After Critical Fixes)
1. **Syntax validation:** `yamllint .github/workflows/*.yml`
2. **Dry run:** Use workflow_dispatch with a known package
3. **Monitor logs:** Check for proper step execution order

### Integration Tests
1. **Manual trigger:** Test each workflow via workflow_dispatch
2. **Automated trigger:** Push package.json change to test repo
3. **Cache rebuild:** Verify package-cache.json updates correctly
4. **Monitor workflow:** Check 15-minute cron execution

### Regression Tests
1. **Multi-package:** Test repo with multiple packages
2. **Failed publish:** Test with invalid NPM_TOKEN
3. **Network issues:** Test with blocked registry URL

## Risk Assessment

### Low Risk
- **YAML syntax fixes:** Simple structural correction
- **Adding env vars:** Standard GitHub Actions practice
- **Health checks:** Fail fast, clear errors

### Medium Risk
- **Runner fallbacks:** May have different environments
- **Mitigation:** Use continue-on-error for fallback runners

### Minimal Risk
- **All changes are in CI/CD only** - no application code affected
- **Can rollback instantly** via git revert
- **Test in forked repo first** if extra caution needed

## Rollback Plan

If issues arise:

1. **Immediate revert:**
   ```bash
   git revert HEAD
   git push
   ```

2. **Manual workflow run:**
   - Use GitHub UI to run last known good workflow
   - Select previous commit ref

3. **Emergency bypass:**
   - Temporarily disable workflows
   - Publish packages manually via npm CLI
   - Fix issues without time pressure

## Files to Modify

### Must Change
1. `.github/workflows/publish-upm.yml` - Fix step structure (lines 31-48)
2. `.github/workflows/publish-unpublished.yml` - Add GH_TOKEN (line 288)

### Should Change
3. `.github/workflows/monitor-publishes.yml` - Add runner fallback
4. All workflows - Add health checks and debug vars

### Could Change
5. `README.md` - Add status badges
6. `docs/troubleshooting.md` - Document new error patterns
7. `.github/workflows/notify.yml` - Create notification workflow

## Success Criteria

✅ **Critical Success:**
- publish-upm.yml runs without syntax errors
- Package publishing works via push trigger
- Cache rebuild completes with authentication

✅ **Full Success:**
- All three workflows run without errors
- Fallback runners configured
- Health checks prevent bad publishes
- Clear error messages for debugging

## Time Estimate

- **Critical fixes:** 10 minutes
- **Testing:** 20 minutes
- **Robustness improvements:** 45 minutes
- **Documentation updates:** 15 minutes
- **Total:** ~90 minutes for complete implementation

## Unresolved Questions

1. **Should we add GitHub-hosted runner fallback?**
   - Pro: Always available
   - Con: Different environment, no port 80 fix
   - Recommendation: Yes, with continue-on-error

2. **How often do ARC runners go down?**
   - Recent history shows good stability
   - Last 10 monitor runs all succeeded
   - Recommendation: Low priority for fallback

3. **Should we version the workflow template?**
   - Currently copied to each repo manually
   - Could use workflow_call for centralization
   - Recommendation: Consider for v2.0

4. **NPM registry rate limits?**
   - Code has retry logic with exponential backoff
   - No documented limits for private registry
   - Recommendation: Monitor and adjust if needed

## Next Steps

After fixes applied:
1. Monitor next scheduled runs (cron jobs)
2. Update all registered repositories with fixed workflow
3. Run full batch publish to clear backlog
4. Document lessons learned
5. Consider workflow centralization for easier updates