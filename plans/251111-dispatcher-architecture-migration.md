# Dispatcher Architecture Migration Plan

**Date**: 2025-11-11
**Status**: Planning
**Priority**: High
**Security**: Production-Ready (maintains A security score)

---

## Overview

Migrate from monolithic workflow in each repository to centralized dispatcher-based architecture where:
- **Dispatcher Workflow** (in each repo): Minimal, stable, detects changes & triggers handler
- **Handler Workflow** (in UPMAutoPublisher): Single source of truth, all publishing logic

**Key Benefit**: Update publishing logic ONCE instead of updating 20+ repositories.

---

## Current Architecture Analysis

### Workflow: `publish-upm.yml` (814 lines)

**Deployed to**: Each repository (20+ repos)

**Features to Preserve**:
1. **Triggers**:
   - Push to master/main with package.json changes
   - Manual workflow_dispatch with optional package_path

2. **Security Features**:
   - Explicit permissions (contents: read, actions: write)
   - Job/step timeouts (20min job, 15min step)
   - Input validation (semver, package name, version format)
   - Registry URL validation
   - GITHUB_WORKSPACE validation
   - Markdown injection prevention
   - Command injection prevention via jq
   - Temp file cleanup with trap

3. **Publishing Logic**:
   - Auto-detect changed package.json files (git diff)
   - Extract package name/version via jq
   - Version existence check on registry
   - Version rollback prevention (semver comparison)
   - Rate limit handling (exponential backoff)
   - Retry logic (3 attempts for publish, 5 for view)
   - Package size warnings (configurable threshold)
   - Registry health check
   - Node.js version verification
   - Post-publish verification

4. **Discord Notifications**:
   - Thread ID: `1437635998109957181`
   - Success notification with package details
   - Failure notification with error details
   - Package tracking: `old-version → new-version`
   - Uses file redirection (not pipes) for package_details
   - Rich embeds with repository, commit, author info

5. **Audit Logging**:
   - Complete jq construction (no interpolation)
   - 90-day retention (configurable)
   - Comprehensive metadata

6. **Environment Configuration**:
   - `UPM_REGISTRY` (org variable, default: https://upm.the1studio.org/)
   - `NPM_TOKEN` (org secret)
   - `DISCORD_WEBHOOK_UPM` (org secret)
   - `USE_SELF_HOSTED_RUNNERS` (org variable)
   - `AUDIT_LOG_RETENTION_DAYS` (org variable, default: 90)
   - `PACKAGE_SIZE_THRESHOLD_MB` (org variable, default: 50)

7. **Multi-Package Support**:
   - Process all changed packages in commit
   - Continue on failure (track failed packages)
   - Clear summary (published/skipped/failed counts)

8. **Error Handling**:
   - Comprehensive debug information on failure
   - Common issue checks (file existence, permissions, NPM_TOKEN)
   - Graceful degradation

**Current Pain Points**:
- Workflow duplicated in 20+ repositories
- Updating logic requires 20+ PRs
- Version drift across repositories
- Hard to test changes before deployment
- Notification improvements require mass updates

---

## Target Architecture

### 1. Dispatcher Workflow (in each repo)

**File**: `.github/workflows/upm-publish-dispatcher.yml` (~100 lines)

**Responsibilities**:
- Detect package.json changes
- Extract basic info (repo, commit, changed files)
- Trigger UPMAutoPublisher via repository_dispatch
- NEVER CHANGES (stable interface)

**Triggers**:
- Push to master/main with package.json changes
- Manual workflow_dispatch with optional package_path

**Data Sent to Handler**:
```json
{
  "event_type": "upm-publish-request",
  "client_payload": {
    "repository": "The1Studio/UnityBuildScript",
    "ref": "refs/heads/master",
    "sha": "abc123...",
    "commit_message": "Bump version to 1.2.11",
    "commit_author": "John Doe",
    "changed_files": ["Assets/Core/package.json"],
    "trigger_type": "push|workflow_dispatch",
    "package_path": "Assets/Core/package.json"  // only if manual
  }
}
```

**Key Design**:
- Minimal logic (just detection & dispatch)
- Uses `gh` CLI for repository_dispatch
- Requires `GH_PAT` to trigger cross-repo workflow
- Fail-fast if dispatch fails
- Clear logging

### 2. Handler Workflow (in UPMAutoPublisher)

**File**: `.github/workflows/handle-publish-request.yml` (~800 lines)

**Responsibilities**:
- Receive repository_dispatch events
- Clone target repository at specific commit
- Run ALL current publishing logic
- Send Discord notifications
- Create audit logs

**Trigger**:
```yaml
on:
  repository_dispatch:
    types: [upm-publish-request]
```

**Workflow Steps**:
1. Validate payload
2. Clone target repo (`gh repo clone org/repo -- --depth 1`)
3. Checkout specific commit (`git checkout $sha`)
4. Run detection/publishing logic (same as current)
5. Send notifications
6. Upload audit logs

**Key Design**:
- ALL business logic here (single source of truth)
- Supports both auto and manual triggers
- Same security features as current
- Same Discord notification logic
- Same audit logging

---

## Detailed Implementation Plan

### Phase 1: Create Handler Workflow (Week 1)

**File**: `.github/workflows/handle-publish-request.yml`

**Tasks**:

1. **Setup Trigger & Validation** (2 hours)
   ```yaml
   on:
     repository_dispatch:
       types: [upm-publish-request]

   jobs:
     handle-publish:
       runs-on: [self-hosted, arc, the1studio, org]
       timeout-minutes: 30
   ```
   - Add payload validation
   - Extract repository info
   - Validate required fields

2. **Clone Target Repository** (2 hours)
   - Use `gh repo clone` with depth 1
   - Checkout specific SHA from payload
   - Validate clone success
   - Set working directory

3. **Port Publishing Logic** (8 hours)
   - Copy detection logic from publish-upm.yml (lines 113-550)
   - Adapt file paths (already in cloned repo)
   - Keep ALL security features:
     - Input validation
     - Rate limiting
     - Retry logic
     - Version checking
     - Package size warnings
   - Test with mock payloads

4. **Port Discord Notifications** (4 hours)
   - Copy notification logic (lines 603-803)
   - Adapt to use payload data:
     - Repository from `client_payload.repository`
     - Commit from `client_payload.sha`
     - Author from `client_payload.commit_author`
   - Maintain package_details tracking
   - Test with actual Discord webhook

5. **Port Audit Logging** (2 hours)
   - Copy audit log creation (lines 552-601)
   - Add dispatcher metadata:
     - Original repository
     - Trigger source
     - Dispatch timestamp
   - Upload with same retention

6. **Error Handling** (2 hours)
   - Clone failures
   - Checkout failures
   - Publishing failures (already handled)
   - Notification to source repo (optional)

**Deliverable**: Fully functional handler workflow (tested with manual dispatch)

### Phase 2: Create Dispatcher Workflow Template (Week 2)

**File**: `.github/workflows/upm-publish-dispatcher.yml`

**Tasks**:

1. **Trigger Configuration** (1 hour)
   ```yaml
   on:
     push:
       branches: [master, main]
       paths: ['**/package.json']
     workflow_dispatch:
       inputs:
         package_path:
           description: 'Path to package.json (optional)'
           required: false
   ```

2. **Detection Logic** (3 hours)
   - Git diff for changed files
   - Handle workflow_dispatch input
   - Extract file list
   - Validate files exist
   - Build changed_files array

3. **Payload Construction** (2 hours)
   - Repository: `${{ github.repository }}`
   - Ref: `${{ github.ref }}`
   - SHA: `${{ github.sha }}`
   - Commit message: `git log -1 --pretty=%s`
   - Author: `git log -1 --pretty='%an'`
   - Changed files array
   - Trigger type
   - Package path (if manual)

4. **Dispatch to Handler** (3 hours)
   ```bash
   gh api repos/The1Studio/UPMAutoPublisher/dispatches \
     -X POST \
     -f event_type='upm-publish-request' \
     -F client_payload=@payload.json
   ```
   - Require GH_PAT secret
   - Validate dispatch success
   - Log dispatch URL for tracking
   - Error handling if dispatch fails

5. **Testing & Validation** (3 hours)
   - Test with real repository
   - Verify payload format
   - Check handler receives correctly
   - Validate end-to-end flow

**Deliverable**: Minimal, stable dispatcher template ready for deployment

### Phase 3: Testing & Validation (Week 2-3)

**Test Repositories** (pick 3 diverse repos):
1. Single package repo (UnityBuildScript)
2. Multi-package repo (TheOneFeature)
3. Complex repo (UITemplate)

**Test Scenarios**:

1. **Auto Trigger Tests**:
   - Single package.json change
   - Multiple package.json changes
   - Version already exists (skip)
   - Invalid version format
   - Publishing failure

2. **Manual Trigger Tests**:
   - Specific package path
   - All packages (empty path)
   - Non-existent path

3. **Error Scenarios**:
   - Dispatcher: No GH_PAT
   - Dispatcher: Dispatch fails
   - Handler: Clone fails
   - Handler: Checkout fails
   - Handler: NPM_TOKEN missing
   - Handler: Registry unreachable
   - Handler: Rate limiting

4. **Notification Tests**:
   - Success notification format
   - Package details display
   - Failure notification
   - Discord thread targeting

5. **Security Tests**:
   - Malicious package names
   - Command injection attempts
   - Markdown injection
   - Large package warnings

**Validation Checklist**:
- [ ] All security features preserved
- [ ] Discord notifications identical
- [ ] Audit logs complete
- [ ] Error handling comprehensive
- [ ] Performance acceptable (<30 min)
- [ ] No regressions vs current

**Deliverable**: Validated dispatcher + handler system

### Phase 4: Deployment Strategy (Week 3-4)

**Approach**: Gradual rollout with rollback capability

**Stage 1: Deploy Handler** (Day 1)
1. Merge `handle-publish-request.yml` to UPMAutoPublisher
2. Test manually with repository_dispatch API
3. Verify logs, notifications, audit trails
4. Keep disabled (don't announce yet)

**Stage 2: Pilot Deployment** (Days 2-5)
1. Select 2 low-traffic repos
2. Deploy dispatcher via registration system:
   ```json
   {
     "url": "https://github.com/The1Studio/PilotRepo1",
     "status": "pending-dispatcher"  // new status
   }
   ```
3. Update registration workflow to deploy dispatcher instead
4. Monitor for 3 days
5. Verify all features working
6. Compare with control repos (still using old workflow)

**Stage 3: Gradual Rollout** (Days 6-15)
1. Deploy to 25% of repos (5 repos)
   - Wait 2 days, monitor
2. Deploy to 50% of repos (10 repos)
   - Wait 2 days, monitor
3. Deploy to 75% of repos (15 repos)
   - Wait 2 days, monitor
4. Deploy to 100% of repos (20 repos)
   - Wait 3 days, monitor

**Stage 4: Cleanup** (Days 16-20)
1. Verify all repos using dispatcher
2. Archive old publish-upm.yml in each repo
3. Update documentation
4. Announce completion

**Rollback Plan**:
- Keep old workflow files in repos (rename to .backup)
- If issues found, revert by renaming back
- Handler can be disabled anytime (workflow_dispatch only)
- Dispatcher minimal, low risk

**Monitoring**:
- GitHub Actions dashboard
- Discord notifications
- Audit logs
- Registry publish counts
- Error rates

**Deliverable**: All repositories migrated to dispatcher architecture

### Phase 5: Documentation & Training (Week 4)

**Documents to Create**:

1. **Architecture Overview** (`docs/dispatcher-architecture.md`)
   - System diagram
   - Workflow interaction
   - Payload format
   - Error handling

2. **Migration Guide** (`docs/dispatcher-migration-guide.md`)
   - Why we migrated
   - What changed for users (nothing!)
   - Troubleshooting dispatcher issues
   - Rollback procedures

3. **Maintenance Guide** (`docs/handler-maintenance.md`)
   - Updating handler logic
   - Testing changes
   - Deploying updates
   - No PR bombardment needed

4. **Update CLAUDE.md**:
   - New architecture section
   - Dispatcher vs handler responsibilities
   - How to make changes
   - Testing procedures

**Developer Communication**:
- Slack announcement
- Document advantages (faster updates, consistent behavior)
- Highlight: "You don't need to do anything!"
- Share troubleshooting guide

**Deliverable**: Complete documentation suite

---

## Files to Modify/Create/Delete

### Create (New Files)

**In UPMAutoPublisher**:
- `.github/workflows/handle-publish-request.yml` - Handler workflow (~800 lines)
- `docs/dispatcher-architecture.md` - Architecture documentation
- `docs/dispatcher-migration-guide.md` - Migration guide
- `docs/handler-maintenance.md` - Maintenance procedures
- `tests/payloads/sample-push-payload.json` - Test payload
- `tests/payloads/sample-manual-payload.json` - Test payload
- `scripts/test-dispatcher.sh` - Testing script

**Template File**:
- `.github/workflows/upm-publish-dispatcher.yml` - Dispatcher template (~100 lines)

### Modify

**In UPMAutoPublisher**:
- `config/repositories.json`:
  - Add `dispatcher_enabled: boolean` field
  - Track migration status
- `config/schema.json`:
  - Add dispatcher_enabled to schema
- `.github/workflows/register-repos.yml`:
  - Support deploying dispatcher instead of full workflow
  - Check `dispatcher_enabled` flag
- `README.md`:
  - Update architecture section
  - Add dispatcher explanation
  - Update workflow description
- `CLAUDE.md`:
  - Add dispatcher architecture section
  - Update workflow references
- `docs/architecture-decisions.md`:
  - Add ADR-011: Dispatcher Architecture
  - Rationale and consequences

### Delete (Future)

**In Target Repositories** (after successful migration):
- `.github/workflows/publish-upm.yml` - Replace with dispatcher
  - Keep backup: `.github/workflows/publish-upm.yml.pre-dispatcher`

---

## Testing Strategy

### Unit Tests

**Dispatcher Logic**:
- File detection (git diff)
- Payload construction
- Dispatch API call

**Handler Logic**:
- Payload validation
- Repository cloning
- Publishing logic (already tested)

### Integration Tests

**End-to-End Flow**:
1. Create test commit in target repo
2. Dispatcher triggers
3. Handler receives
4. Publishing executes
5. Notification sent
6. Audit logged

**Error Scenarios**:
- Network failures
- API rate limits
- Invalid payloads
- Clone failures
- Publishing failures

### Load Tests

**Concurrent Requests**:
- 5 repos push simultaneously
- Handler queues properly
- No race conditions
- All processed successfully

### Security Tests

**Payload Validation**:
- Malformed JSON
- Missing required fields
- Oversized payloads
- Injection attempts

**Authentication**:
- Missing GH_PAT
- Expired GH_PAT
- Missing NPM_TOKEN

---

## Security Considerations

### Dispatcher Security

**Threats**:
- Unauthorized dispatch triggering
- Payload tampering
- GH_PAT exposure

**Mitigations**:
- GH_PAT required (org secret)
- Payload signed by GitHub
- No sensitive data in payload
- Validate payload structure

### Handler Security

**Threats**:
- Malicious payloads
- Repository compromise
- Command injection
- Markdown injection

**Mitigations**:
- Preserve ALL current security features:
  - Input validation
  - jq-only JSON construction
  - No string interpolation
  - Temp file permissions (600)
  - Trap cleanup
- Validate repository ownership
- Clone from trusted org only
- Checkout specific SHA (immutable)

### Communication Security

**repository_dispatch**:
- GitHub-native mechanism
- Authenticated via token
- Logged in audit trail
- Rate limited by GitHub

---

## Performance Considerations

### Dispatcher Performance

**Current**: Runs in target repo (~5-10 min)
**Dispatcher**: <2 min (just detection + dispatch)
**Improvement**: 3-8 min faster for user

**Latency**:
- Dispatch API call: <1s
- Handler queue time: <30s
- Total added latency: <1 min

### Handler Performance

**Current**: N/A (runs in each repo)
**Handler**: Same as current (~5-10 min per request)
**Concurrency**: Multiple handlers can run in parallel

**Bottlenecks**:
- Repository cloning (~30s-2min)
- npm operations (rate limited)
- Discord API (rate limited)

**Optimizations**:
- Shallow clone (depth 1) - DONE
- Parallel processing - Not needed (5 min is acceptable)
- Cached dependencies - Not beneficial (different repos)

### Scalability

**Current System**:
- 20 repos = 20 workflow runs in parallel
- Each uses target repo runner

**Dispatcher System**:
- 20 dispatchers = 20 quick jobs
- Handler processes sequentially/parallel in UPMAutoPublisher

**Capacity**:
- Self-hosted runners: 2+ available
- Queue depth: Unlimited (GitHub managed)
- Realistic load: <5 concurrent publishes

---

## Risks & Mitigations

### Risk 1: Handler Becomes Single Point of Failure

**Impact**: If handler fails, NO publishing works
**Probability**: Medium
**Severity**: High

**Mitigations**:
- Comprehensive error handling
- Retry logic preserved
- Fallback: Manual publish still possible
- Monitoring & alerts
- Rollback plan ready
- Keep old workflows as backup

### Risk 2: Dispatch Failures

**Impact**: Package updates don't trigger publish
**Probability**: Low
**Severity**: Medium

**Mitigations**:
- GH_PAT validation in dispatcher
- Clear error messages
- Retry logic in dispatcher
- Manual trigger still available
- Monitoring dispatch failures

### Risk 3: Payload Size Limits

**Impact**: Large payloads rejected
**Probability**: Low
**Severity**: Low

**GitHub Limits**: 64KB payload max

**Current Payload Size**:
```
{
  repository: ~50 bytes
  ref: ~30 bytes
  sha: ~40 bytes
  commit_message: ~200 bytes
  author: ~50 bytes
  changed_files: ~100 bytes per file
}
Total: ~500 bytes + (N files × 100)
```

**Max Files**: 600+ files (extremely unlikely)

**Mitigation**:
- Truncate changed_files if needed
- Fall back to "process all" if truncated

### Risk 4: Version Drift During Migration

**Impact**: Some repos on old workflow, some on new
**Probability**: High (gradual rollout)
**Severity**: Low

**Mitigations**:
- Track migration status in config
- Clear communication
- Identical behavior in both systems
- No breaking changes

### Risk 5: Lost Features During Port

**Impact**: Features work differently or missing
**Probability**: Medium
**Severity**: High

**Mitigations**:
- Comprehensive feature checklist
- Side-by-side testing
- User validation
- Rollback capability

---

## Rollback Plan

### Trigger Conditions

Rollback if:
- Handler failure rate >10%
- Notification failures >20%
- User-reported issues >3
- Critical security issue discovered
- Performance degradation >2x

### Rollback Steps

**Immediate** (within 1 hour):
1. Disable handler workflow (workflow_dispatch only)
2. Revert dispatchers to old publish-upm.yml:
   ```bash
   cd target-repo
   git mv .github/workflows/publish-upm.yml.pre-dispatcher \
          .github/workflows/publish-upm.yml
   git commit -m "Rollback to pre-dispatcher workflow"
   git push
   ```
3. Communicate to team
4. Monitor for stability

**Complete** (within 24 hours):
1. Update all repos (via registration system)
2. Remove dispatcher workflows
3. Restore old workflows
4. Test each repo
5. Document lessons learned

**Post-Mortem** (within 1 week):
- Analyze failure cause
- Fix handler issues
- Re-test thoroughly
- Plan second migration attempt

---

## Success Criteria

### Technical Metrics

- [ ] Handler success rate: >99%
- [ ] Dispatcher overhead: <2 min
- [ ] End-to-end latency: <12 min (vs current 10 min)
- [ ] Zero notification failures
- [ ] Zero security regressions
- [ ] All 20 repos migrated successfully

### Functional Criteria

- [ ] All current features work identically
- [ ] Discord notifications identical format
- [ ] Audit logs complete and accurate
- [ ] Manual trigger works
- [ ] Auto trigger works
- [ ] Multi-package support works
- [ ] Error handling comprehensive

### User Experience Criteria

- [ ] No user action required
- [ ] No workflow changes for developers
- [ ] Publishing time unchanged or faster
- [ ] Clear error messages
- [ ] Documentation complete

### Maintenance Criteria

- [ ] Handler updates don't require repo PRs
- [ ] Single workflow to maintain
- [ ] Testing process documented
- [ ] Rollback tested and ready

---

## Timeline Summary

| Week | Phase | Key Deliverables |
|------|-------|------------------|
| **Week 1** | Handler Development | Complete handle-publish-request.yml |
| **Week 2** | Dispatcher + Testing | upm-publish-dispatcher.yml template, validation |
| **Week 3** | Pilot Deployment | 2 repos migrated, monitoring |
| **Week 4** | Gradual Rollout | All 20 repos migrated |
| **Week 4** | Documentation | Complete docs, training materials |

**Total Duration**: 4 weeks
**Effort**: 120-160 hours
**Team Size**: 1-2 developers

---

## TODO Task List

### Phase 1: Handler Workflow
- [ ] Create `handle-publish-request.yml` skeleton
- [ ] Implement payload validation
- [ ] Add repository clone logic
- [ ] Port package detection (lines 113-550)
- [ ] Port Discord notifications (lines 603-803)
- [ ] Port audit logging (lines 552-601)
- [ ] Test with mock payloads
- [ ] Test with real Discord webhook
- [ ] Document handler workflow

### Phase 2: Dispatcher Workflow
- [ ] Create `upm-publish-dispatcher.yml` template
- [ ] Implement file detection (git diff)
- [ ] Build payload construction
- [ ] Add dispatch API call
- [ ] Test dispatcher isolation
- [ ] Validate payload format
- [ ] Test end-to-end flow

### Phase 3: Testing
- [ ] Create test payloads
- [ ] Test single package publish
- [ ] Test multi-package publish
- [ ] Test manual trigger
- [ ] Test auto trigger
- [ ] Test error scenarios (10+ cases)
- [ ] Test security scenarios
- [ ] Load test (5 concurrent)
- [ ] Performance benchmark

### Phase 4: Deployment
- [ ] Deploy handler to UPMAutoPublisher
- [ ] Select 2 pilot repos
- [ ] Deploy dispatcher to pilots
- [ ] Monitor pilots for 3 days
- [ ] Deploy to 25% repos (5)
- [ ] Monitor 2 days
- [ ] Deploy to 50% repos (10)
- [ ] Monitor 2 days
- [ ] Deploy to 75% repos (15)
- [ ] Monitor 2 days
- [ ] Deploy to 100% repos (20)
- [ ] Monitor 3 days
- [ ] Archive old workflows

### Phase 5: Documentation
- [ ] Write `dispatcher-architecture.md`
- [ ] Write `dispatcher-migration-guide.md`
- [ ] Write `handler-maintenance.md`
- [ ] Update README.md
- [ ] Update CLAUDE.md
- [ ] Update architecture-decisions.md (ADR-011)
- [ ] Create testing guide
- [ ] Announce to team

---

## Unresolved Questions

1. **Handler Concurrency**: Should we limit concurrent handler runs? Or let GitHub queue naturally?
   - **Recommendation**: Let GitHub queue (simpler, self-regulating)

2. **Dispatcher Timeout**: What's acceptable timeout for dispatcher (detection + dispatch)?
   - **Current**: 20 min job timeout
   - **Recommendation**: 5 min (should be <2 min normally)

3. **Payload Compression**: Should we compress changed_files if large?
   - **Current**: No compression
   - **Recommendation**: Truncate after 50 files, fall back to "process all"

4. **Handler Notifications**: Should handler notify source repo on failures?
   - **Current**: No cross-repo notifications
   - **Recommendation**: Discord only (existing mechanism)

5. **Version Tracking**: Should we track dispatcher version in payload?
   - **Recommendation**: Yes, add `dispatcher_version: "1.0.0"` for debugging

6. **Backward Compatibility**: Support old direct publish during migration?
   - **Recommendation**: Yes, keep both working during gradual rollout

7. **Testing Frequency**: How often test handler changes?
   - **Recommendation**: Every change, use pilot repos as canaries

8. **Monitoring Dashboard**: Need dedicated dashboard for dispatcher/handler?
   - **Recommendation**: Phase 2 enhancement, use GitHub Actions UI for now

---

## Post-Migration Opportunities

### Phase 2 Enhancements (Future)

1. **Batch Publishing**:
   - Queue multiple dispatch events
   - Process in batches
   - Reduce redundant clones

2. **Advanced Notifications**:
   - Slack integration
   - Email summaries
   - Daily/weekly digests

3. **Metrics & Analytics**:
   - Publish frequency dashboard
   - Failure rate tracking
   - Performance trends
   - Package popularity

4. **Smart Caching**:
   - Cache cloned repos (30 min TTL)
   - Reuse for multiple packages
   - Faster subsequent publishes

5. **Pre-Publish Validation**:
   - Dependency checks
   - Breaking change detection
   - Automated testing
   - Quality gates

6. **Changelog Generation**:
   - Auto-generate from commits
   - Update package.json changelog
   - Link to PRs

7. **Rollback Support**:
   - Deprecate versions
   - Unpublish mechanism
   - Version pinning

---

## References

- **Current Workflow**: `.github/workflows/publish-upm.yml`
- **Architecture Decisions**: `docs/architecture-decisions.md`
- **Security Audit**: `docs/security-improvements.md`
- **Registration System**: `docs/registration-system-overview.md`
- **GitHub API**: [Repository Dispatch](https://docs.github.com/en/rest/repos/repos#create-a-repository-dispatch-event)

---

**Plan Status**: Ready for Implementation
**Next Steps**: Begin Phase 1 - Handler Workflow Development
**Questions?** See Unresolved Questions section above
