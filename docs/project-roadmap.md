# Project Roadmap

**Project**: UPM Auto Publisher
**Version**: 1.2.0
**Status**: Production (Active)
**Last Updated**: 2025-11-12

---

## Table of Contents

1. [Current Status](#current-status)
2. [Completed Milestones](#completed-milestones)
3. [Active Development](#active-development)
4. [Planned Enhancements](#planned-enhancements)
5. [Future Considerations](#future-considerations)
6. [Known Limitations](#known-limitations)
7. [Technical Debt](#technical-debt)

---

## Current Status

### Version 1.2.0 (November 2025)

**Status**: ✅ Production (Stable)
**Security Score**: A (Hardened Production)
**Active Repositories**: 21 of 27
**Daily Publishes**: ~20 packages/day
**Success Rate**: >99%

**Key Achievements**:
- ✅ Dispatcher architecture fully migrated
- ✅ AI-powered changelog generation operational
- ✅ Security score upgraded from A- to A (10 additional fixes)
- ✅ All 27 repositories registered (21 active, 5 skip, 1 pending conversion)
- ✅ 90% maintenance overhead reduction achieved
- ✅ Zero regressions during migration

---

## Completed Milestones

### Phase 0: Initial Release (v1.0.0 - January 2025)

**Goal**: Eliminate manual publishing steps

**Completed Features**:
- ✅ Monolithic workflow template (`publish-upm.yml`)
- ✅ Automatic package.json change detection
- ✅ Organization-level NPM token authentication
- ✅ Multi-package repository support
- ✅ Basic error handling and retry logic
- ✅ No git tag requirement (simplified workflow)

**Outcome**: **75% time savings** (7 steps → 2 steps per release)

---

### Phase 1: Security Hardening (v1.1.0 - October 2025)

**Goal**: Achieve production-ready security posture

**Completed Security Fixes** (18 total):
- ✅ 6 CRITICAL: Command injection prevention, input validation
- ✅ 7 HIGH: Token exposure, rate limiting, registry validation
- ✅ 5 MAJOR: Docker security, temp file permissions, error handling

**New Features**:
- ✅ Configurable registry URL (organization variable)
- ✅ Comprehensive audit logging (90-day retention)
- ✅ Version rollback prevention (semver comparison)
- ✅ Registry health checks
- ✅ Package size warnings (configurable threshold)
- ✅ npm retry logic with exponential backoff

**Outcome**: **Security score C → A-** (Production Ready)

---

### Phase 2: Dispatcher Migration + Enhanced Security (v1.2.0 - November 2025)

**Goal**: Reduce maintenance overhead and fix remaining security issues

**Architecture Changes**:
- ✅ Created centralized handler (`handle-publish-request.yml`, 693 lines)
- ✅ Created lightweight dispatcher (`upm-publish-dispatcher.yml`, 129 lines)
- ✅ Migrated all 27 repositories to dispatcher architecture
- ✅ Achieved 90% maintenance reduction (1 file vs 27 files)
- ✅ Zero regressions during gradual rollout

**Additional Security Fixes** (10 total):
- ✅ 3 HIGH: Command injection (complete jq construction), markdown injection, race conditions
- ✅ 5 MAJOR: Rate limiting, token validation, temp file security
- ✅ 2 MEDIUM: Docker image pinning, Dependabot configuration

**New Features**:
- ✅ AI-powered changelog generation (Gemini API)
- ✅ Enhanced Discord notifications with rich embeds
- ✅ GitHub concurrency control (replaces file locking)
- ✅ Form-based repository registration
- ✅ Package cache for fast lookups
- ✅ Daily monitoring and auditing workflows

**Outcome**:
- **Security score A- → A** (Hardened Production)
- **Maintenance overhead: 90% reduction**
- **28 total security issues fixed across v1.1.0 and v1.2.0**

---

## Active Development

### Current Sprint (November-December 2025)

**Focus**: Stabilization and documentation

**In Progress**:
- 🔄 Comprehensive documentation update (this roadmap included)
- 🔄 Monitoring dashboard planning
- 🔄 Performance optimization research

**Planned for Completion**:
- ✅ Complete documentation suite (15+ docs)
- ✅ Pre-deployment validation enhancements
- ✅ Migration plan archival

---

## Planned Enhancements

### Short-Term (Q1 2026)

#### 1. Pre-Publish Testing Integration
**Priority**: P1 (High)
**Effort**: 3 weeks
**Status**: Planned

**Description**: Run Unity tests before publishing packages to prevent broken packages from being published.

**Requirements**:
- Integrate with Unity Test Runner
- Support both Edit Mode and Play Mode tests
- Configurable test timeout
- Fail publish if tests fail
- Report test results in Discord notification

**Benefits**:
- Prevent publishing broken packages
- Increase package quality
- Reduce hotfix publishes

**Implementation**:
```yaml
# In handler workflow
- name: Run Unity tests
  run: |
    unity -runTests -testPlatform EditMode
    unity -runTests -testPlatform PlayMode

- name: Publish only if tests pass
  if: steps.tests.outcome == 'success'
  run: npm publish
```

**Acceptance Criteria**:
- AC1: Tests run automatically before publish
- AC2: Publish blocked if tests fail
- AC3: Test results included in notifications
- AC4: Configurable per repository (opt-in)

---

#### 2. Breaking Change Detection
**Priority**: P2 (Medium)
**Effort**: 2 weeks
**Status**: Planned

**Description**: Analyze commits and package changes to automatically detect breaking changes and suggest correct semver bump.

**Requirements**:
- Parse commit messages for breaking change keywords
- Analyze API changes in code
- Compare current vs previous package exports
- Suggest major/minor/patch version bump
- Warn if semver bump doesn't match change type

**Benefits**:
- Prevent incorrect semver usage
- Better dependency management
- Clear change communication

**Detection Patterns**:
- **Major** (breaking): `BREAKING CHANGE:`, removed public API, renamed public methods
- **Minor** (feature): `feat:`, new public API, optional parameters added
- **Patch** (bugfix): `fix:`, internal changes only

**Acceptance Criteria**:
- AC1: Detects breaking changes from commits
- AC2: Warns if version bump incorrect
- AC3: Suggests correct version
- AC4: Does not block publish (warning only)

---

#### 3. Dependency Vulnerability Scanning
**Priority**: P1 (High)
**Effort**: 2 weeks
**Status**: Planned

**Description**: Scan package dependencies for known vulnerabilities before publishing.

**Requirements**:
- Integrate with npm audit
- Check against known vulnerability databases
- Block publish if critical vulnerabilities found
- Report vulnerabilities in Discord
- Allow override for false positives

**Implementation**:
```bash
# In handler workflow
npm audit --audit-level=high

if [ $? -ne 0 ]; then
  echo "❌ Critical vulnerabilities found"
  exit 1
fi
```

**Benefits**:
- Prevent publishing vulnerable packages
- Improve security posture
- Proactive vulnerability management

**Acceptance Criteria**:
- AC1: Scans dependencies before publish
- AC2: Blocks critical vulnerabilities
- AC3: Reports findings in Discord
- AC4: Allows override with --force flag

---

### Medium-Term (Q2-Q3 2026)

#### 4. Multi-Registry Support
**Priority**: P2 (Medium)
**Effort**: 3 weeks
**Status**: Researching

**Description**: Support publishing to different registries per repository (e.g., public packages to npmjs.com, private to upm.the1studio.org).

**Use Cases**:
- Open source packages → npmjs.com
- Internal packages → upm.the1studio.org
- Customer-specific packages → customer.registry.com

**Implementation Approach**:
```json
// In repositories.json
{
  "url": "https://github.com/The1Studio/PublicPackage",
  "status": "active",
  "registry": "https://registry.npmjs.org/"  // NEW: per-repo registry
}
```

**Challenges**:
- Multiple NPM tokens (different registries)
- Registry-specific configuration
- Backward compatibility

**Acceptance Criteria**:
- AC1: Configure registry per repository
- AC2: Support multiple NPM tokens
- AC3: Backward compatible (default to UPM_REGISTRY)
- AC4: Validation for registry URLs

---

#### 5. Package Analytics Dashboard
**Priority**: P2 (Medium)
**Effort**: 4 weeks
**Status**: Design Phase

**Description**: Track and visualize package download statistics, usage trends, and popularity.

**Metrics to Track**:
- Daily/weekly/monthly downloads per package
- Most popular packages
- Version adoption rate
- Breaking change impact
- Package health score

**Tech Stack**:
- Data collection: npm registry API
- Storage: GitHub Actions artifacts or external DB
- Visualization: GitHub Pages + Chart.js

**Benefits**:
- Understand package usage
- Guide deprecation decisions
- Identify popular features
- Measure breaking change impact

**Acceptance Criteria**:
- AC1: Collects download metrics daily
- AC2: Visualizes trends over time
- AC3: Identifies top packages
- AC4: Accessible to organization members

---

#### 6. Slack Integration
**Priority**: P3 (Low)
**Effort**: 1 week
**Status**: Backlog

**Description**: Add Slack notifications in addition to Discord for teams using Slack.

**Implementation**:
```yaml
# Parallel notifications
- name: Send Discord notification
  run: notify_discord

- name: Send Slack notification  # NEW
  run: notify_slack
```

**Configuration**:
- SLACK_WEBHOOK_UPM organization secret
- Same notification format as Discord
- Configurable per team/channel

**Acceptance Criteria**:
- AC1: Supports Slack webhooks
- AC2: Same rich formatting as Discord
- AC3: Configurable (Discord, Slack, or both)
- AC4: Does not break Discord notifications

---

### Long-Term (Q4 2026+)

#### 7. Package Deprecation Workflow
**Priority**: P2 (Medium)
**Effort**: 2 weeks
**Status**: Backlog

**Description**: Mark packages as deprecated on registry with migration guidance.

**Use Cases**:
- Sunset old packages
- Migrate to new package names
- Guide users to alternatives

**Implementation**:
```bash
# Manual workflow trigger
npm deprecate com.theone.oldpackage "Deprecated: Use com.theone.newpackage instead"
```

**Acceptance Criteria**:
- AC1: Manual workflow to deprecate packages
- AC2: Provide deprecation message
- AC3: Notify team in Discord
- AC4: Update package-cache.json

---

#### 8. Automated Dependency Updates
**Priority**: P3 (Low)
**Effort**: 3 weeks
**Status**: Research

**Description**: Automatically create PRs to update package dependencies.

**Workflow**:
1. Daily scan for dependency updates
2. Create PR with updated package.json
3. Run tests automatically
4. Auto-merge if tests pass

**Challenges**:
- Unity package compatibility
- Breaking changes in dependencies
- Testing overhead

**Acceptance Criteria**:
- AC1: Scans for updates daily
- AC2: Creates PRs automatically
- AC3: Runs tests before merge
- AC4: Configurable per repository (opt-in)

---

#### 9. Package Rollback Support
**Priority**: P3 (Low)
**Effort**: 2 weeks
**Status**: Backlog

**Description**: Unpublish or rollback specific package versions in case of critical issues.

**Use Cases**:
- Critical bug in published package
- Security vulnerability discovered
- Accidental publish

**Implementation**:
```bash
# Manual workflow trigger
npm unpublish com.theone.package@1.2.11 --force

# Or deprecate instead
npm deprecate com.theone.package@1.2.11 "Contains critical bug, use 1.2.10"
```

**Caution**: npm unpublish has restrictions (24-hour window, not if downloaded)

**Acceptance Criteria**:
- AC1: Manual workflow to unpublish/deprecate
- AC2: Requires manual approval
- AC3: Updates package-cache.json
- AC4: Notifies team in Discord

---

## Future Considerations

### Ideas Under Evaluation

#### Changelog Enforcement
**Description**: Require changelog entries before allowing publish

**Pros**:
- Forces documentation of changes
- Improves package maintainability
- Better communication to users

**Cons**:
- Adds friction to publish process
- May slow down hotfixes
- AI changelog already provides this

**Decision**: **Not pursuing** (AI changelog sufficient)

---

#### Automatic Package Website Generation
**Description**: Generate documentation websites from package README and CHANGELOG

**Pros**:
- Professional package presentation
- Better discoverability
- Centralized documentation

**Cons**:
- Maintenance overhead
- Unclear value (GitHub READMEs sufficient)

**Decision**: **Deferred** (low priority, unclear ROI)

---

#### Cross-Registry Package Mirroring
**Description**: Mirror packages across multiple registries for redundancy

**Pros**:
- High availability
- Geographic distribution
- Disaster recovery

**Cons**:
- Complexity
- Sync challenges
- Cost

**Decision**: **Not needed** (single registry sufficient)

---

## Known Limitations

### Current Limitations

1. **Single Registry Support**
   - Only supports one UPM registry per organization
   - Workaround: Configure per repo (planned in Q2 2026)

2. **No Pre-Publish Testing**
   - Does not run tests before publishing
   - Workaround: Manual testing before commit (automated testing planned Q1 2026)

3. **npm Only**
   - Does not support yarn or pnpm
   - Workaround: None needed (npm sufficient for Unity packages)

4. **Sequential Publishing**
   - Processes one publish request at a time per runner
   - Workaround: Multiple runners (2-3 active, scalable to 10+)

5. **No Package Analytics**
   - Cannot track package downloads or usage
   - Workaround: Manual npm registry queries (dashboard planned Q2 2026)

6. **Discord Only**
   - Notifications only via Discord
   - Workaround: None (Slack integration planned Q3 2026)

7. **Manual Rollback**
   - No automated package unpublish/rollback
   - Workaround: Manual npm unpublish (automation planned Q4 2026+)

---

## Technical Debt

### Priority 1 (Address in Q1 2026)

#### TD1: Workflow File Size
**Issue**: Handler workflow is 693 lines (too large)
**Impact**: Hard to maintain, review, and test
**Solution**: Modularize into separate reusable workflows
**Effort**: 1 week

---

#### TD2: Hardcoded Thread ID
**Issue**: Discord thread ID hardcoded in handler
**Impact**: Cannot change notification channel without code change
**Solution**: Move to organization variable
**Effort**: 1 day

---

#### TD3: Limited Test Coverage
**Issue**: No automated tests for workflows
**Impact**: Regressions require manual testing
**Solution**: Add workflow integration tests
**Effort**: 2 weeks

---

### Priority 2 (Address in Q2-Q3 2026)

#### TD4: Package Cache Rebuild Performance
**Issue**: Full cache rebuild scans all repositories (slow)
**Impact**: ~5-10 minutes for 27 repositories
**Solution**: Incremental updates (only changed repos)
**Effort**: 1 week

---

#### TD5: Error Message Localization
**Issue**: All messages in English only
**Impact**: International teams may have language barrier
**Solution**: Add i18n support (if needed)
**Effort**: 2 weeks
**Priority**: Low (English sufficient for now)

---

#### TD6: Monitoring Dashboard Absence
**Issue**: No centralized dashboard for metrics
**Impact**: Metrics scattered across workflows
**Solution**: Build analytics dashboard (planned Q2 2026)
**Effort**: 4 weeks

---

### Priority 3 (Low Priority / Nice to Have)

#### TD7: Gemini API Dependency
**Issue**: Changelog generation tied to single AI provider
**Impact**: Vendor lock-in, rate limits
**Solution**: Abstract AI interface, support multiple providers (OpenAI, Claude, etc.)
**Effort**: 1 week

---

#### TD8: Legacy Template Maintenance
**Issue**: `publish-upm.yml` kept as backup but not updated
**Impact**: Fallback may have outdated logic
**Solution**: Archive legacy template (dispatcher stable enough)
**Effort**: 1 day

---

## Metrics & Success Criteria

### Current Metrics (as of 2025-11-12)

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| **Publish Success Rate** | 99.5% | >99% | ✅ Exceeds |
| **Time to Publish** | 5-15 min | <30 min | ✅ Excellent |
| **Security Score** | A | A- or better | ✅ Exceeds |
| **Active Repositories** | 21/27 (78%) | 80% | ✅ Near target |
| **Daily Publishes** | ~20 | - | ✅ Stable |
| **Maintenance Overhead** | 10% of original | <20% | ✅ Exceeds |
| **Developer Time Saved** | 80% | 75% | ✅ Exceeds |

### 2026 Goals

| Metric | Current | 2026 Target | Gap |
|--------|---------|-------------|-----|
| **Active Repositories** | 21 | 30 | +9 |
| **Pre-Publish Test Coverage** | 0% | 80% | +80% |
| **Vulnerability Scan Coverage** | 0% | 100% | +100% |
| **Package Analytics** | No | Yes | Dashboard |
| **Multi-Registry Support** | No | Yes | Feature |
| **Success Rate** | 99.5% | 99.8% | +0.3% |

---

## Conclusion

UPM Auto Publisher has successfully achieved its primary goals:
- ✅ 80% developer time savings
- ✅ 99.5% publish success rate
- ✅ A-level security hardening
- ✅ 90% maintenance reduction through dispatcher architecture

The roadmap focuses on **quality improvements** (testing, security scanning) and **observability enhancements** (analytics dashboard) rather than major architectural changes. The dispatcher architecture provides a stable foundation for future enhancements without requiring widespread changes across repositories.

**Next Major Milestones**:
1. Q1 2026: Pre-publish testing integration
2. Q2 2026: Multi-registry support + analytics dashboard
3. Q3 2026: Slack integration
4. Q4 2026: Package deprecation workflow

---

**Document Owner**: The1Studio DevOps Team
**Review Cycle**: Quarterly
**Next Review**: 2026-02-12
**Last Updated**: 2025-11-12
