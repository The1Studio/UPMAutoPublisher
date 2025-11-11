# GitHub Actions Workflow Failure Analysis

**Date**: 2025-11-10
**Workflow Run**: https://github.com/The1Studio/TheOneFeature/actions/runs/19230428683
**Job ID**: 54967439386
**Status**: Failed (FALSE POSITIVE)

---

## Executive Summary

**CRITICAL BUG IDENTIFIED**: Workflow verification step has a parsing bug causing false-positive failures. Package was successfully published but verification failed due to incorrect output format parsing.

**Impact**:
- Package `com.theone.feature.core@1.0.1` WAS published successfully
- Workflow incorrectly reported failure
- Verification logic fails to parse npm output correctly

---

## Timeline Analysis

```
11:44:06 - Workflow started
11:44:07 - Publishing com.theone.feature.core@1.0.1...
11:44:08 - ✅ Successfully published com.theone.feature.core@1.0.1
11:44:08 - 🔍 Verifying publication...
11:44:08 - sleep 3 (waiting for registry indexing)
11:44:11 - ❌ Verification failed: Package not found on registry
11:44:11 - Workflow exited with code 1
```

**Duration**:
- Publish to verify: ~3 seconds
- Total workflow time: ~5 seconds

---

## Root Cause Analysis

### 1. What Failed?

The **verification step** failed to detect the published package.

**Workflow Output**:
```
❌ Verification failed: Package not found on registry
   Expected: 1.0.1
   Got: 'not found'
⚠️  Package may have been published but not yet indexed
```

### 2. Why Did It Fail?

**BUG IN VERIFICATION LOGIC**: The workflow uses incorrect parsing to extract version from npm output.

**Current Code** (Lines ~380-390 in `.github/workflows/publish-upm.yml`):
```bash
published_version=$(npm_view_with_retry "${package_name}@${new_version}" 2>/dev/null | grep '^version:' | awk '{print $2}' || echo "")
```

**The Problem**:
- `npm view` output format does NOT contain `^version:` prefix
- The grep pattern `'^version:'` matches NOTHING
- Result: `published_version` is always empty string

**npm view Output Format**:
```
com.theone.feature.core@1.0.1 | MIT | deps: none | versions: 2
Core foundation classes and utilities for TheOne Feature framework
https://theonegamestudio.com

dist
.tarball: https://upm.the1studio.org/com.theone.feature.core/-/com.theone.feature.core-1.0.1.tgz
.shasum: e94e6d86475fde79f7dcc5a5d6a9e75fb420a01e
.integrity: sha512-vWnqnUU6WlimLJp6JbX1U+QI8OQAVh8ws+84nf3eqlQWA6OBlBybm98HKHMCScnHHC9dSmyuOF4nUGEg7zKQMw==

dist-tags:
latest: 1.0.1

published 8 minutes ago
```

Notice: **NO `version:` line exists in this format!**

### 3. Verification Tests

#### Test 1: Current Logic (FAILS)
```bash
$ npm view "com.theone.feature.core@1.0.1" --registry https://upm.the1studio.org/ | grep '^version:'
(no output - empty string)
```

#### Test 2: Direct Field Query (WORKS)
```bash
$ npm view "com.theone.feature.core@1.0.1" version --registry https://upm.the1studio.org/
1.0.1
```

#### Test 3: JSON Output (WORKS)
```bash
$ npm view "com.theone.feature.core@1.0.1" --registry https://upm.the1studio.org/ --json | jq -r '.version'
1.0.1
```

#### Test 4: Registry Direct Check (WORKS)
```bash
$ curl -s https://upm.the1studio.org/com.theone.feature.core/1.0.1 | jq -r '.version'
1.0.1

$ curl -s https://upm.the1studio.org/com.theone.feature.core | jq -r '.["dist-tags"].latest'
1.0.1
```

### 4. Expected Behavior

Workflow should:
1. ✅ Publish package to registry (WORKING)
2. ✅ Wait for registry indexing (WORKING - 3 seconds)
3. ✅ Verify package exists on registry (BROKEN - parsing bug)
4. ✅ Report success if package found (NEVER REACHES due to #3)

### 5. Actual Behavior

Workflow:
1. ✅ Publishes package successfully
2. ✅ Waits 3 seconds
3. ❌ Fails to extract version (parsing bug returns empty string)
4. ❌ Reports failure incorrectly
5. ❌ Increments `failed` counter
6. ❌ Exits with code 1

---

## Impact Assessment

### Severity: **MAJOR** 🔥

**Why Major?**
- Every single publish will fail verification (100% failure rate)
- False-positive failures cause confusion
- Packages ARE published but workflow reports failure
- Developers may re-run workflow unnecessarily
- Audit logs show failures when publishes succeed

### Affected Systems
- ✅ Package Publishing: **WORKING** (packages DO get published)
- ❌ Verification Step: **BROKEN** (always fails)
- ❌ Workflow Status: **BROKEN** (false failures)
- ❌ Audit Logs: **INACCURATE** (reports failures incorrectly)
- ❌ Developer Experience: **DEGRADED** (confusing error messages)

### Evidence Package IS Published

1. **Registry Check**:
   ```bash
   $ curl -s https://upm.the1studio.org/com.theone.feature.core | jq '.["dist-tags"].latest'
   "1.0.1"
   ```

2. **NPM View**:
   ```bash
   $ npm view com.theone.feature.core@1.0.1 --registry https://upm.the1studio.org/
   com.theone.feature.core@1.0.1 | MIT | deps: none | versions: 2
   published 12 minutes ago
   ```

3. **Workflow Logs**:
   ```
   ✅ Successfully published com.theone.feature.core@1.0.1
   + com.theone.feature.core@1.0.1
   ```

---

## Fix Required

### Option 1: Use Direct Field Query (RECOMMENDED)

**Change**:
```bash
# OLD (BROKEN):
published_version=$(npm_view_with_retry "${package_name}@${new_version}" 2>/dev/null | grep '^version:' | awk '{print $2}' || echo "")

# NEW (FIXED):
published_version=$(npm_view_with_retry "${package_name}@${new_version}" version 2>/dev/null || echo "")
```

**Why This Works**:
- `npm view <package> version` returns ONLY the version number
- No parsing required
- Clean, simple, reliable
- Exit code indicates success/failure

**Testing**:
```bash
$ npm view com.theone.feature.core@1.0.1 version --registry https://upm.the1studio.org/
1.0.1

$ npm view com.theone.feature.core@9.9.9 version --registry https://upm.the1studio.org/ || echo "not found"
not found
```

### Option 2: Use JSON Output (ALTERNATIVE)

**Change**:
```bash
# NEW (ALTERNATIVE):
published_version=$(npm_view_with_retry "${package_name}@${new_version}" --json 2>/dev/null | jq -r '.version // empty' || echo "")
```

**Why This Works**:
- JSON output is structured and reliable
- jq extracts version field accurately
- Handles missing fields with `// empty`

**Downside**:
- Requires `jq` dependency (though it's already used elsewhere in workflow)
- Slightly more complex

### Option 3: Check Dist-Tags (ROBUST)

**Change**:
```bash
# NEW (MOST ROBUST):
# First check if package exists at all
if npm_view_with_retry "${package_name}" --json 2>/dev/null | jq -e ".versions[\"$new_version\"]" >/dev/null; then
  published_version="$new_version"
else
  published_version=""
fi
```

**Why This Works**:
- Checks if version exists in versions object
- Works even if dist-tags not updated yet
- Most robust against timing issues

---

## Recommended Fix

**Use Option 1** (direct field query) because:
1. ✅ Simplest implementation
2. ✅ No new dependencies
3. ✅ Minimal code change
4. ✅ Most readable
5. ✅ Fastest execution

**File to Modify**: `.github/workflows/publish-upm.yml`

**Line to Change**: ~385

**Before**:
```bash
published_version=$(npm_view_with_retry "${package_name}@${new_version}" 2>/dev/null | grep '^version:' | awk '{print $2}' || echo "")
```

**After**:
```bash
published_version=$(npm_view_with_retry "${package_name}@${new_version}" version 2>/dev/null || echo "")
```

**Also Update `npm_view_with_retry` Function** (~line 150):

The function needs to pass through the additional `version` argument:

**Before**:
```bash
npm_view_with_retry() {
  local package_spec="$1"
  # ... rest of function
  if output=$(npm view "$package_spec" --registry "$UPM_REGISTRY" 2>&1); then
```

**After**:
```bash
npm_view_with_retry() {
  local package_spec="$1"
  shift  # Remove first argument
  local extra_args="$@"  # Capture remaining arguments (like 'version')
  # ... rest of function
  if output=$(npm view "$package_spec" $extra_args --registry "$UPM_REGISTRY" 2>&1); then
```

---

## Testing Plan

### Unit Test
```bash
# Test successful case
npm view com.theone.feature.core@1.0.1 version --registry https://upm.the1studio.org/
# Expected: 1.0.1

# Test failure case (non-existent version)
npm view com.theone.feature.core@9.9.9 version --registry https://upm.the1studio.org/ 2>&1
# Expected: npm ERR! 404 No match found for version 9.9.9

# Test with retry function simulation
published_version=$(npm view com.theone.feature.core@1.0.1 version --registry https://upm.the1studio.org/ 2>/dev/null || echo "")
if [ "$published_version" = "1.0.1" ]; then
  echo "✅ PASS: Version extracted correctly"
else
  echo "❌ FAIL: Got '$published_version'"
fi
```

### Integration Test
1. Create test package with new version
2. Run workflow on test repository
3. Verify workflow shows success
4. Check audit log shows correct `published: 1, failed: 0`

### Regression Test
1. Test with non-existent version (should fail gracefully)
2. Test with network timeout (should retry)
3. Test with rate limiting (should backoff)
4. Test with multiple packages (should continue on failure)

---

## Workaround (Immediate)

**For existing workflows**:
1. Check registry directly to confirm package published
2. Ignore workflow failure if package exists on registry
3. Manually verify with: `npm view <package>@<version> --registry https://upm.the1studio.org/`

**Audit Log Correction**:
- Workflow reported: `published: 0, failed: 0` (incorrect)
- Actual result: `published: 1, failed: 0`
- Package `com.theone.feature.core@1.0.1` WAS successfully published

---

## Related Issues

### Similar Issues in Codebase
Check if any other scripts use `npm view | grep '^version:'` pattern:
```bash
grep -r "npm view.*grep.*version:" .
```

### Documentation Updates Needed
1. `docs/troubleshooting.md` - Add section on verification failures
2. `docs/architecture-decisions.md` - Document npm output format assumptions
3. `README.md` - Add note about false-positive failures in older versions

---

## References

- Workflow Run: https://github.com/The1Studio/TheOneFeature/actions/runs/19230428683
- NPM CLI Documentation: https://docs.npmjs.com/cli/v10/commands/npm-view
- Registry API: https://upm.the1studio.org/com.theone.feature.core
- Audit Log Artifact: https://github.com/The1Studio/TheOneFeature/actions/runs/19230428683/artifacts/4518552450

---

## Conclusion

**Package Publishing**: ✅ WORKING
**Verification Logic**: ❌ BROKEN
**Workflow Status**: ❌ FALSE POSITIVE FAILURE

**Action Required**: Update verification logic in `.github/workflows/publish-upm.yml` to use direct field query instead of grep parsing.

**Priority**: HIGH (causes confusion, false failures, inaccurate audit logs)

**Estimated Fix Time**: 5 minutes
**Estimated Test Time**: 10 minutes
**Total Time**: 15 minutes
