# Architecture Decisions

This document explains the design choices made for the UPM auto-publishing system and the reasoning behind them.

## Decision Log

### ADR-001: GitHub Actions Over Jenkins

**Decision:** Use GitHub Actions for CI/CD instead of existing Jenkins infrastructure.

**Context:**
- The1Studio has Jenkins at jenkins.the1studio.org
- Need automated UPM package publishing
- Multiple repositories need the same workflow

**Options Considered:**
1. GitHub Actions
2. Jenkins CI/CD
3. Custom Git hooks

**Decision:** GitHub Actions

**Rationale:**
- **Native Integration:** Works seamlessly with GitHub repositories
- **Distributed:** Each repo has its own workflow (no single point of failure)
- **Free:** No additional infrastructure costs for public/private repos
- **Easy to Maintain:** Workflow files in repo, version controlled
- **Team Familiar:** Most developers know GitHub Actions
- **Portable:** Can easily copy workflow to new repos

**Consequences:**
- ✅ No Jenkins configuration needed
- ✅ Workflow lives with code
- ✅ Easy to replicate across repos
- ⚠️ Need to manage GitHub secrets
- ⚠️ Limited to GitHub-hosted runners

---

### ADR-002: Trigger on Commit, Not Tags

**Decision:** Trigger workflow on commit to master/main when package.json changes, not on git tag creation.

**Context:**
- Original process: Update version → commit → create tag → push both → manually publish
- Want to simplify developer workflow

**Options Considered:**
1. Trigger on tag push (upm/*)
2. Trigger on version change in package.json
3. Manual workflow dispatch

**Decision:** Trigger on package.json version change

**Rationale:**
- **Simpler Workflow:** Developers just update version and push
- **No Tag Management:** No need to remember tag naming conventions
- **Atomic Operation:** Version change and publish happen together
- **Reduces Errors:** Can't forget to create tag or push it
- **Better DX:** Fewer steps = fewer mistakes

**Consequences:**
- ✅ Simplified developer workflow (2 steps instead of 7)
- ✅ No tag management needed
- ✅ Less chance of version/tag mismatch
- ⚠️ Relies on version detection logic
- ⚠️ Can't publish without version bump

---

### ADR-003: Organization-Level NPM Token

**Decision:** Use single NPM token shared across all repositories via GitHub organization secret.

**Context:**
- Multiple repositories need to publish to upm.the1studio.org
- Need secure token management
- Want easy onboarding for new repos

**Options Considered:**
1. Organization-level secret (shared)
2. Per-repository secrets
3. GitHub App with token generation

**Decision:** Organization-level secret

**Rationale:**
- **Single Management Point:** One token to rotate/update
- **Easy Onboarding:** New repos automatically have access
- **Consistent Security:** Same token policy across org
- **Simpler Maintenance:** Don't need to update each repo individually

**Consequences:**
- ✅ Easy to add new repositories
- ✅ Single token rotation process
- ✅ Consistent across organization
- ⚠️ If compromised, affects all repos
- ⚠️ Need org admin access to update

---

### ADR-004: Auto-Discovery Instead of Config File

**Decision:** Workflow auto-discovers packages by scanning for package.json changes, rather than requiring a config file listing packages.

**Context:**
- Repositories have different structures
- Some have multiple packages
- Want minimal configuration

**Options Considered:**
1. Config file listing all packages
2. Auto-discovery via git diff
3. Hardcoded package paths

**Decision:** Auto-discovery

**Rationale:**
- **Zero Configuration:** Works out of the box
- **Flexible:** Handles any package location
- **Maintainable:** No config to keep in sync
- **Scalable:** Works for 1 or 100 packages
- **Self-Documenting:** package.json itself is the config

**Consequences:**
- ✅ No extra config files needed
- ✅ Works with any repo structure
- ✅ Handles multi-package repos automatically
- ⚠️ Relies on git diff working correctly
- ⚠️ Could theoretically detect non-UPM package.json files

---

### ADR-005: Version Existence Check Before Publishing

**Decision:** Query registry to check if version exists before attempting to publish.

**Context:**
- Don't want to fail workflow if version already published
- Want idempotent workflow (can re-run safely)
- Need to handle re-runs after failures

**Options Considered:**
1. Always attempt publish (let npm error)
2. Check version exists first
3. Track published versions in repo

**Decision:** Check before publishing

**Rationale:**
- **Idempotent:** Can re-run workflow safely
- **Better UX:** Clear "skipped" messages vs errors
- **Faster:** Don't waste time attempting publish
- **Cleaner Logs:** Explicit skip reason

**Consequences:**
- ✅ Safe to re-run workflows
- ✅ Clear feedback on why skipped
- ✅ No unnecessary publish attempts
- ⚠️ Extra network call per package
- ⚠️ Slight complexity in workflow

---

### ADR-006: Continue on Error (Multi-Package)

**Decision:** When multiple packages change, continue publishing remaining packages even if one fails.

**Context:**
- Some repos have multiple packages
- One package failure shouldn't block others
- Want maximum automation

**Options Considered:**
1. Stop on first error
2. Continue and report all errors at end
3. Fail workflow but mark as warning

**Decision:** Continue on error

**Rationale:**
- **Maximize Success:** Get as many packages published as possible
- **Clear Reporting:** Summary shows what failed
- **Developer Friendly:** Don't have to retry entire workflow
- **Partial Progress:** Better than all-or-nothing

**Consequences:**
- ✅ More packages published per run
- ✅ Clear error summary
- ✅ Partial success possible
- ⚠️ Workflow can be green with failures
- ⚠️ Need to check logs carefully

---

### ADR-007: No Automatic Tag Creation

**Decision:** Don't create git tags automatically after publishing.

**Context:**
- Originally planned to create upm/{package}/{version} tags
- User feedback: don't need tags anymore
- Simpler is better

**Options Considered:**
1. Auto-create tags after publish
2. No tags at all
3. Optional tag creation

**Decision:** No automatic tags

**Rationale:**
- **Simplification:** Less git operations
- **User Request:** Explicitly requested no tags
- **Permission Simple:** No need for write access to repo
- **Faster Workflow:** Fewer operations
- **Version in Registry:** Can always check registry for versions

**Consequences:**
- ✅ Simpler workflow
- ✅ No permission issues
- ✅ Faster execution
- ✅ No tag management needed
- ⚠️ Can't see versions from git tags alone
- ⚠️ Must query registry for version history

---

### ADR-008: Repository Registry for Documentation

**Decision:** Maintain config/repositories.json as documentation of which repos use auto-publishing.

**Context:**
- Need to track which repos have auto-publishing
- Want to know package locations
- Helpful for onboarding and maintenance

**Options Considered:**
1. No registry (just docs)
2. JSON registry file
3. Database or external system

**Decision:** JSON registry file

**Rationale:**
- **Simple:** Just a JSON file
- **Versioned:** In git with repo
- **Human Readable:** Easy to review
- **Scriptable:** Can parse with jq
- **Documentation:** Serves as reference

**Consequences:**
- ✅ Easy to see all registered repos
- ✅ Can validate with JSON schema
- ✅ Version controlled
- ⚠️ Manual updates needed
- ⚠️ Can get out of sync

---

### ADR-009: GH_PAT for Workflow Triggering

**Decision:** Use GH_PAT (Personal Access Token) instead of GITHUB_TOKEN for operations that need to trigger other workflows.

**Context:**
- Manual registration form commits to master and needs to trigger register-repos workflow
- Register-repos workflow creates PRs in target repositories
- GITHUB_TOKEN has security limitation: commits made by github-actions[bot] using GITHUB_TOKEN don't trigger other workflows (prevents infinite loops)

**Options Considered:**
1. Use GITHUB_TOKEN (built-in, automatic)
2. Use GH_PAT (Personal Access Token)
3. Use GitHub App with installation token
4. Deploy keys per repository

**Decision:** GH_PAT (Personal Access Token)

**Rationale:**
- **Workflow Triggering:** Only GH_PAT and GitHub Apps can trigger workflows from automated commits
- **Simplicity:** PAT is simpler to set up than GitHub App
- **Organization-Wide:** Single token works for all repos in organization
- **Scoped Permissions:** Can limit to `repo` and `workflow` scopes only
- **Manageable:** Standard GitHub token management and rotation process

**Consequences:**
- ✅ Enables fully automated registration flow (form → commit → trigger → PR)
- ✅ Single token for all workflow automation needs
- ✅ Standard GitHub token rotation procedures apply
- ⚠️ Must rotate token periodically (recommended: 90 days)
- ⚠️ Token has broader permissions than GITHUB_TOKEN
- ⚠️ If compromised, attacker can create workflows and PRs across org
- ⚠️ Requires organization admin to create and manage

**Security Mitigations:**
- Set 90-day expiration on token
- Workflows validate GH_PAT before use (fail fast if expired)
- Clear error messages guide users to rotation procedures
- Document rotation process in configuration guide
- GitHub emails warnings before expiration

**Validation Implementation:**
```yaml
- name: Validate GH_PAT
  run: |
    if ! gh auth status 2>/dev/null; then
      echo "❌ GH_PAT is invalid or expired"
      echo "See: docs/configuration.md#gh_pat-setup"
      exit 1
    fi
```

---

### ADR-010: Automatic PR Merge with Graceful Degradation

**Decision:** Enable auto-merge on created PRs with graceful failure handling.

**Context:**
- Register-repos workflow creates PRs in target repositories
- Users must manually merge PRs to complete setup
- Want to reduce manual overhead where possible
- Some repositories have branch protection requiring reviews

**Options Considered:**
1. Always require manual merge
2. Auto-merge with --auto flag (graceful failure)
3. Auto-merge with branch protection bypass
4. Conditional auto-merge based on repo settings

**Decision:** Auto-merge with graceful degradation

**Rationale:**
- **Reduced Friction:** PRs merge automatically when checks pass in repos without protection
- **Faster Deployment:** No waiting for manual merge in simple cases
- **Graceful Failure:** If auto-merge fails (branch protection), PR stays open for manual merge
- **No Breaking Changes:** Works with any repository configuration
- **User Choice:** Repositories can enable/disable via branch protection
- **Clean History:** Uses squash strategy for atomic commits

**Implementation:**
```yaml
gh pr merge "$pr_url" --auto --squash 2>&1 || true
```

**Consequences:**
- ✅ Faster setup for repos without branch protection
- ✅ PRs merge automatically when CI passes
- ✅ Backwards compatible (works with all repos)
- ✅ Graceful failure doesn't break workflow
- ⚠️ Silent failure if auto-merge not available
- ⚠️ May merge without human review in some repos
- ⚠️ Requires repository auto-merge feature enabled

**When Auto-Merge Works:**
- ✅ Repository has auto-merge feature enabled
- ✅ No required reviewers configured
- ✅ All required status checks pass
- ✅ Branch protection allows auto-merge

**When Manual Merge Required:**
- ⏭️ Branch protection requires reviews
- ⏭️ Required status checks haven't passed
- ⏭️ Auto-merge feature disabled
- ⏭️ Repository settings don't allow auto-merge

**Error Handling:**
- Workflow logs warning if auto-merge fails
- PR remains open for manual merge
- User sees clear message in PR comments
- No workflow failure (graceful degradation)

---

## Design Principles

### 1. Developer Experience First

**Principle:** Minimize steps required to publish a package.

**Implementation:**
- Auto-detection of changes
- No manual triggers
- Clear error messages
- Self-documenting configuration

### 2. Fail Safe

**Principle:** System should be safe to use even if mistakes are made.

**Implementation:**
- Check version exists before publishing
- Continue on errors (multi-package)
- Idempotent operations
- Can re-run workflows safely

### 3. Organization-Wide Consistency

**Principle:** Same workflow and behavior across all repositories.

**Implementation:**
- Single workflow template
- Organization-level secrets
- Consistent naming conventions
- Standardized documentation

### 4. Minimal Configuration

**Principle:** Should work with minimal or zero configuration.

**Implementation:**
- Auto-discovery of packages
- No required config files
- Works with any repo structure
- Convention over configuration

### 5. Observable and Debuggable

**Principle:** Easy to understand what happened and why.

**Implementation:**
- Detailed logging
- Clear skip/error messages
- Summary at end
- Troubleshooting guide

## Future Considerations

### Potential Enhancements

1. **Slack/Discord Notifications:**
   - Notify team when packages published
   - Alert on failures
   - Weekly summary

2. **Changelog Generation:**
   - Auto-generate from commits
   - Update package.json `_upm.changelog`
   - Link to PR/commits

3. **Validation Rules:**
   - Semver validation
   - Breaking change detection
   - Dependency version checks

4. **Metrics and Analytics:**
   - Track publish frequency
   - Monitor failure rates
   - Package usage statistics

5. **Rollback Support:**
   - Deprecate versions
   - Unpublish mechanism
   - Version pinning

### Non-Goals

These were explicitly decided against:

1. **Automatic Version Bumping:** Developers control version numbers
2. **Complex Branching:** Only master/main, no feature branches
3. **Pre-release Channels:** No alpha/beta/rc support
4. **Manual Approval:** Fully automated, no gates
5. **Cross-Registry Publish:** Only upm.the1studio.org

## References

- [Setup Instructions](setup-instructions.md)
- [NPM Token Setup](npm-token-setup.md)
- [Troubleshooting](troubleshooting.md)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## Changelog

- **2025-10-16:** Added ADR-009 (GH_PAT for workflow triggering) and ADR-010 (auto-merge with graceful degradation)
- **2025-01-16:** Initial architecture decisions documented
- **ADR-007:** Added no automatic tag creation decision based on user feedback
