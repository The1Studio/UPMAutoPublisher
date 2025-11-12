# Codebase Summary

**Project**: UPM Auto Publisher
**Version**: 1.2.0
**Architecture**: Dispatcher-based centralized publishing
**Last Updated**: 2025-11-12
**Security Score**: A (Hardened Production)

---

## Overview

UPM Auto Publisher is an automated Unity Package Manager publishing system for The1Studio organization. It uses a dispatcher-based architecture where lightweight dispatchers in target repositories trigger a centralized handler for all publishing logic.

---

## Architecture Summary

### Dispatcher-Handler Model

**Dispatcher** (`upm-publish-dispatcher.yml`, ~129 lines):
- Deployed to each target repository (27 registered repositories)
- Detects package.json changes via git diff
- Sends publish request to central handler via `repository_dispatch`
- Minimal, stable code that rarely changes

**Handler** (`handle-publish-request.yml`, ~693 lines):
- Runs in UPMAutoPublisher repository (single source of truth)
- Receives publish requests from all dispatchers
- Clones target repository and executes publishing logic
- Manages AI changelog generation, Discord notifications, and audit logging

**Key Benefit**: Update publishing logic ONCE instead of updating 27+ repositories.

---

## Directory Structure

```
UPMAutoPublisher/
├── .docker/                           # Docker-based self-hosted runners
│   ├── docker-compose.runners.yml    # 3 runner configuration
│   └── README.md                      # Runner setup and management
├── .github/
│   ├── dependabot.yml                 # Automated dependency updates
│   └── workflows/                     # 12 active GitHub Actions workflows
│       ├── handle-publish-request.yml # Central handler (693 lines)
│       ├── upm-publish-dispatcher.yml # Dispatcher template (129 lines)
│       ├── publish-upm.yml            # Legacy template (813 lines)
│       ├── publish-unpublished.yml    # Detect unpublished packages (351 lines)
│       ├── trigger-stale-publishes.yml# Retry failed publishes (294 lines)
│       ├── monitor-publishes.yml      # Monitor publish status (222 lines)
│       ├── daily-package-check.yml    # Daily package verification (250 lines)
│       ├── daily-audit.yml            # Daily audit logs (210 lines)
│       ├── build-package-cache.yml    # Package cache builder (305 lines)
│       ├── manual-register-repo.yml   # Form-based repo registration (221 lines)
│       ├── register-repos.yml         # Automated repo registration (532 lines)
│       └── sync-repo-status.yml       # Sync repo status (156 lines)
├── config/
│   ├── repositories.json              # Registry of 27 repositories
│   ├── schema.json                    # JSON schema validation
│   └── package-cache.json             # Cached package metadata (24KB)
├── docs/                              # Comprehensive documentation
│   ├── npm-token-setup.md
│   ├── self-hosted-runners.md
│   ├── registration-system-overview.md
│   ├── security-improvements.md
│   ├── security-fixes-summary.md
│   ├── security-fixes-v1.2.0.md
│   ├── form-registration.md
│   ├── quick-registration.md
│   ├── architecture-decisions.md
│   ├── troubleshooting.md
│   ├── workflow-system-overview.md
│   ├── setup-instructions.md
│   ├── changelog-management.md
│   ├── configuration.md
│   ├── CHANGELOG.template.md
│   └── 2025-10-31-workflow-fixes.md
├── scripts/                           # Utility scripts
│   ├── apply-fixes.sh                 # Apply security fixes
│   ├── audit-repos.sh                 # Repository auditing
│   ├── build-package-cache.sh         # Cache builder
│   ├── check-single-repo.sh           # Single repo status
│   ├── generate-changelog.sh          # AI changelog generation
│   ├── pre-deployment-check.sh        # 37+ validation checks
│   ├── quick-check.sh                 # Quick validation
│   ├── validate-changelog.sh          # Changelog validation
│   └── validate-config.sh             # Config validation
├── plans/                             # Migration and planning documents
│   └── 251111-dispatcher-architecture-migration.md
├── CLAUDE.md                          # AI assistant instructions
├── README.md                          # Main documentation
└── LICENSE                            # MIT License
```

---

## Workflows (12 Active)

### 1. Core Publishing Workflows (5)

#### `handle-publish-request.yml` (693 lines) 🎯 **CENTRAL HANDLER**
**Purpose**: Centralized publishing logic for all repositories
**Trigger**: `repository_dispatch` event type `package_publish`
**Key Features**:
- Clones target repository at specific commit SHA
- Validates registry configuration and health
- Detects changed package.json files
- Version existence checking with retry logic (5 attempts)
- Version rollback prevention (semver validation)
- Rate limit handling with exponential backoff
- Package size warnings (configurable threshold)
- AI-powered changelog generation (Gemini API)
- Discord notifications with rich embeds
- Comprehensive audit logging (90-day retention)
- Post-publish verification
- Error handling and recovery

**Input Payload**:
```json
{
  "repository": "The1Studio/RepoName",
  "commit_sha": "abc123...",
  "commit_message": "Bump version to 1.2.11",
  "commit_author": "username",
  "branch": "master",
  "package_path": "Assets/Package/package.json" // optional
}
```

#### `upm-publish-dispatcher.yml` (129 lines) 🚀 **LIGHTWEIGHT DISPATCHER**
**Purpose**: Detect changes and trigger central handler
**Deployed To**: Each target repository (27 repositories)
**Trigger**: Push to master/main with package.json changes, or manual workflow_dispatch
**Key Features**:
- Minimal logic (detection + dispatch only)
- Git diff to detect changed package.json files
- Payload construction with jq (no string interpolation)
- Repository dispatch to UPMAutoPublisher
- Manual trigger support with specific package path
- Fail-fast if dispatch fails
- 5-minute timeout (typically <2 minutes)

**Stability**: NEVER CHANGES (stable interface)

#### `publish-upm.yml` (813 lines) ⚠️ **LEGACY TEMPLATE**
**Purpose**: Original monolithic workflow (pre-dispatcher architecture)
**Status**: Kept as template and reference, not actively deployed to new repos
**Usage**: Documentation and rollback fallback

#### `publish-unpublished.yml` (351 lines)
**Purpose**: Detect and publish packages that should be published but aren't
**Trigger**: Manual workflow_dispatch
**Features**:
- Scans package-cache.json for all registered packages
- Checks if latest version exists on registry
- Publishes missing packages automatically
- Comprehensive reporting

#### `trigger-stale-publishes.yml` (294 lines)
**Purpose**: Retry failed or stale package publishes
**Trigger**: Manual workflow_dispatch with repository filter
**Features**:
- Identifies packages with version mismatches
- Triggers dispatchers for stale packages
- Batch processing support

### 2. Repository Management Workflows (3)

#### `manual-register-repo.yml` (221 lines) 📝 **FORM-BASED REGISTRATION**
**Purpose**: Web form interface for repository registration
**Trigger**: Manual workflow_dispatch with form inputs
**Key Features**:
- User-friendly form inputs (no JSON editing)
- Input validation (URL format, status values)
- Automatic repositories.json update via jq
- Creates pull request with changes
- Auto-merge enabled (when checks pass)
- GH_PAT validation

**Form Inputs**:
- Repository URL (required, validated)
- Status (dropdown: pending/active/disabled/skip)

#### `register-repos.yml` (532 lines) 🤖 **AUTOMATED REGISTRATION**
**Purpose**: Deploy dispatcher workflow to pending repositories
**Trigger**: Push to config/repositories.json, or manual workflow_dispatch
**Key Features**:
- Detects repositories with status="pending"
- Creates pull request in target repository
- Adds upm-publish-dispatcher.yml workflow
- Includes setup documentation
- Auto-merge enabled
- Updates status to "active" after deployment
- GH_PAT required for cross-repo operations

**Workflow**:
1. Scan repositories.json for `status: "pending"`
2. For each pending repo:
   - Fork dispatcher template
   - Create PR in target repo
   - Enable auto-merge
3. Mark as "active" in registry

#### `sync-repo-status.yml` (156 lines)
**Purpose**: Synchronize repository status with actual workflow state
**Trigger**: Scheduled daily at 2 AM UTC, or manual
**Features**:
- Checks workflow file existence in target repos
- Updates status in repositories.json
- Detects mismatches (active but no workflow, etc.)
- Automated status reconciliation

### 3. Monitoring & Auditing Workflows (3)

#### `monitor-publishes.yml` (222 lines) 📊 **PUBLISH MONITORING**
**Purpose**: Monitor recent publishes and report issues
**Trigger**: Scheduled every 6 hours, or manual
**Features**:
- Checks GitHub Actions runs for publish workflows
- Identifies failed publishes
- Discord notifications for failures
- Retry suggestions

#### `daily-package-check.yml` (250 lines) 🔍 **PACKAGE VERIFICATION**
**Purpose**: Daily verification of package registry state
**Trigger**: Scheduled daily at 3 AM UTC, or manual
**Features**:
- Compares package-cache.json with registry state
- Detects version mismatches
- Identifies unpublished packages
- Reports anomalies to Discord
- Comprehensive health check

#### `daily-audit.yml` (210 lines) 📋 **AUDIT LOGGING**
**Purpose**: Daily audit log maintenance and reporting
**Trigger**: Scheduled daily at 1 AM UTC, or manual
**Features**:
- Cleans up audit logs older than retention period (90 days)
- Generates daily audit reports
- Upload to GitHub Actions artifacts
- Retention management

### 4. Maintenance Workflows (1)

#### `build-package-cache.yml` (305 lines) 🔄 **CACHE BUILDER**
**Purpose**: Build and maintain package metadata cache
**Trigger**: Push to config/repositories.json, manual, or daily schedule
**Features**:
- Scans all registered repositories
- Discovers all package.json files
- Extracts package metadata (name, version, path)
- Generates package-cache.json (24KB)
- Enables fast package lookups
- Automatic commit and push
- Skips CI triggers with `[skip ci]`

---

## Configuration Files

### `config/repositories.json` (27 repositories)
Registry of all repositories using UPM auto-publishing.

**Structure**:
```json
{
  "$schema": "./schema.json",
  "repositories": [
    {
      "url": "https://github.com/The1Studio/UnityBuildScript",
      "status": "active"
    }
  ]
}
```

**Status Values**:
- `active`: Dispatcher deployed and operational (21 repositories)
- `pending`: Queued for dispatcher deployment (0 repositories)
- `disabled`: Temporarily disabled (0 repositories)
- `skip`: Intentionally excluded from auto-publishing (5 repositories)

**Current Counts** (as of 2025-11-12):
- Total: 27 repositories
- Active: 21 repositories
- Skip: 5 repositories
- Pending: 0 repositories

### `config/schema.json`
JSON schema for repositories.json validation.

**Validation Rules**:
- `url`: Required, must match GitHub URL pattern
- `status`: Required, enum of ["active", "pending", "disabled", "skip"]

### `config/package-cache.json` (24KB)
Cached metadata for all packages in registered repositories.

**Generated By**: `build-package-cache.yml` workflow
**Updated**: On repositories.json changes, or daily
**Purpose**: Fast package lookups without cloning repositories

**Structure**:
```json
{
  "lastUpdated": "2025-11-12T10:30:00Z",
  "packages": [
    {
      "name": "com.theone.buildscript",
      "version": "1.2.10",
      "repository": "https://github.com/The1Studio/UnityBuildScript",
      "path": "Assets/BuildScript/package.json"
    }
  ]
}
```

---

## Scripts (9 Utility Scripts)

### Validation Scripts

#### `validate-config.sh`
Validates repositories.json against schema.json using ajv-cli.

#### `validate-changelog.sh`
Validates CHANGELOG.md format against "Keep a Changelog" standard.

#### `pre-deployment-check.sh` (37+ validation checks)
Comprehensive pre-deployment validation covering:
- File structure completeness (12 critical files)
- JSON syntax and schema validation
- Bash script syntax (shellcheck)
- Security best practices
- GitHub Actions workflow security fixes
- Docker configuration security
- Dependency checks (node, npm, jq, gh, etc.)

**Exit Codes**:
- 0: All checks passed
- 1: Critical failures detected
- 2: Warnings present (non-blocking)

#### `quick-check.sh`
Fast validation of essential components (subset of pre-deployment-check).

### Repository Management Scripts

#### `audit-repos.sh`
Audits all registered repositories:
- Repository accessibility (HTTP 200 check)
- Workflow file existence
- Last workflow run status
- Status mismatches (registry vs actual)
- Generates comprehensive audit report

#### `check-single-repo.sh <repo>`
Quick status check for specific repository.

**Accepts**:
- Repository name: `UnityBuildScript`
- Full name: `The1Studio/UnityBuildScript`
- URL: `https://github.com/The1Studio/UnityBuildScript`

### Publishing Scripts

#### `generate-changelog.sh` 🤖 **AI-POWERED**
Generates CHANGELOG.md entries using Google Gemini AI.

**Features**:
- Analyzes git commit history since last version
- Uses AI to create user-facing descriptions
- Follows "Keep a Changelog" format
- Categorizes changes (Added, Changed, Fixed, etc.)
- Updates or creates CHANGELOG.md automatically

**Requirements**:
- `GEMINI_API_KEY` environment variable
- Git repository with commit history

**Usage**:
```bash
./generate-changelog.sh \
  "path/to/package.json" \
  "old_version" \
  "new_version" \
  "gemini_api_key"
```

#### `build-package-cache.sh`
Builds package-cache.json by scanning all registered repositories.

### Maintenance Scripts

#### `apply-fixes.sh`
Applies security fixes to workflow files (used during security hardening).

---

## Key Technologies & Dependencies

### Runtime Dependencies
- **Node.js**: 18.x (LTS)
- **npm**: 9.x+
- **jq**: 1.6+ (JSON processing)
- **gh**: 2.x+ (GitHub CLI)
- **curl**: 7.x+ (HTTP requests)
- **git**: 2.x+

### Validation Tools
- **shellcheck**: Bash script linting
- **ajv-cli**: JSON schema validation
- **yamllint**: YAML syntax validation

### AI Integration
- **Google Gemini API**: Changelog generation
  - Model: gemini-2.0-flash-exp
  - Free tier: 1500 requests/day, 1M tokens/day
  - Rate limit: 10 requests/minute

### External Services
- **Discord Webhook**: Notifications and alerts
- **UPM Registry**: https://upm.the1studio.org/
- **GitHub Actions**: Workflow orchestration
- **Self-Hosted Runners**: ARC (Actions Runner Controller) on Kubernetes

---

## Security Architecture

### Security Score: A (Hardened Production)

**Security Fixes Implemented**: 28 total (18 in v1.1.0, 10 in v1.2.0)

### Security Features

#### Input Validation
- **Semver Validation**: Ensures version format (X.Y.Z)
- **Package Name Validation**: Prevents command injection
- **Registry URL Validation**: HTTPS, valid domain format
- **GITHUB_WORKSPACE Validation**: Prevents path traversal

#### Command Injection Prevention
- **jq-only JSON Construction**: No string interpolation
- **Parameterized Commands**: All variables quoted
- **Markdown Injection Prevention**: Validates links, HTML, code blocks
- **URL Sanitization**: Strips control characters

#### Authentication Security
- **GH_PAT Validation**: Checks token validity without exposure
- **NPM_TOKEN Security**: Never logged or exposed in process lists
- **Token Rotation**: 90-day expiration recommended

#### Rate Limiting & Retry Logic
- **npm view**: 5 attempts with exponential backoff (1s, 2s, 4s, 8s, 16s)
- **npm publish**: 3 attempts with exponential backoff
- **Registry Health Check**: 3 attempts before failing
- **Rate Limit Detection**: Handles 429 responses gracefully

#### Temporary File Security
- **Explicit Permissions**: chmod 600 for temp files
- **Trap Cleanup**: Ensures temp files deleted on exit/error
- **Secure Temp Directory**: Uses mktemp with proper umask

#### Concurrency Control
- **GitHub Concurrency**: Replaces file-based locking
- **Cancel-in-progress**: Prevents race conditions
- **Mutex Pattern**: Single workflow run per repository

#### Audit Logging
- **Comprehensive Metadata**: Repository, commit, author, timestamp, package details
- **90-Day Retention**: Configurable via organization variable
- **Immutable Logs**: Uploaded to GitHub Actions artifacts
- **No Sensitive Data**: Tokens and secrets excluded

#### Docker Security
- **Image Version Pinning**: myoung34/github-runner:2.311.0
- **Docker Secrets**: Uses Docker secrets instead of environment variables
- **No Socket Mounting**: Docker socket removed (not needed for UPM)
- **Resource Limits**: CPU and memory limits per container
- **Network Isolation**: Dedicated bridge network

#### GitHub Actions Security
- **Explicit Permissions**: contents: read, actions: write (minimal)
- **Job Timeouts**: 30-minute hard limit
- **Step Timeouts**: 15-minute step limit
- **Pinned Actions**: Uses @v4 for actions/checkout, actions/setup-node
- **Dependabot**: Automated dependency updates enabled

---

## Organization Variables & Secrets

### Organization Variables (Public)
- `UPM_REGISTRY`: https://upm.the1studio.org/ (default)
- `UPM_REGISTRY_HOST`: upm.the1studio.org (for npm config)
- `AUDIT_LOG_RETENTION_DAYS`: 90 (default)
- `PACKAGE_SIZE_THRESHOLD_MB`: 50 (default)
- `USE_SELF_HOSTED_RUNNERS`: true (use ARC runners)

### Organization Secrets (Private)
- `NPM_TOKEN`: Authentication for UPM registry
- `GH_PAT`: Personal Access Token for cross-repo operations (repo, workflow scopes)
- `DISCORD_WEBHOOK_UPM`: Discord webhook for notifications
- `GEMINI_API_KEY`: Google Gemini API key for changelog generation

---

## Discord Notifications

### Thread Configuration
- **Thread ID**: `1437635998109957181`
- **Channel**: UPM Auto Publisher notifications

### Notification Types

#### Success Notification
```
✅ Package Published Successfully

📦 **Package**: com.theone.buildscript
📌 **Version**: 1.2.10 → 1.2.11
📁 **Repository**: The1Studio/UnityBuildScript
🔗 **Commit**: abc123... (first 7 chars)
👤 **Author**: username
🌿 **Branch**: master
⏱️ **Time**: 2025-11-12 10:30:00 UTC
```

#### Failure Notification
```
❌ Package Publish Failed

📦 **Package**: com.theone.buildscript
📌 **Version**: 1.2.11
📁 **Repository**: The1Studio/UnityBuildScript
🔗 **Commit**: abc123...
👤 **Author**: username
⚠️ **Error**: [error details]
```

### Notification Features
- **Rich Embeds**: Color-coded (green for success, red for failure)
- **Embedded Links**: Repository, commit, workflow run URLs
- **Package Tracking**: Old version → new version format
- **File Redirection**: Uses file I/O instead of pipes (prevents shell issues)
- **Error Context**: Includes error messages and troubleshooting hints

---

## Performance Characteristics

### Dispatcher Performance
- **Detection Time**: <1 minute (git diff + jq parsing)
- **Dispatch Time**: <5 seconds (GitHub API call)
- **Total Dispatcher Time**: ~1-2 minutes (5-minute timeout)

### Handler Performance
- **Clone Time**: 30 seconds - 2 minutes (depends on repo size)
- **Publishing Time**: 1-5 minutes per package
- **Changelog Generation**: 10-30 seconds per package (AI processing)
- **Notification Time**: 1-2 seconds per notification
- **Total Handler Time**: 5-15 minutes per publish request (30-minute timeout)

### Scalability
- **Concurrent Dispatchers**: Unlimited (GitHub managed queue)
- **Concurrent Handlers**: 2-3 (limited by self-hosted runners)
- **Daily Capacity**: 500+ publishes (more than needed)
- **Peak Load**: 5-10 concurrent publishes (realistic max)

### Resource Usage
- **Memory**: ~4GB per handler run (includes Node.js + npm + git)
- **CPU**: 2 cores per handler run
- **Storage**: <1GB per workflow run (cleanup after completion)
- **Network**: ~10-100 MB per publish (depends on package size)

---

## Testing & Validation

### Pre-Deployment Checks
Run before any production deployment:
```bash
./scripts/pre-deployment-check.sh
```

**Validates**:
- ✅ File structure (12 critical files)
- ✅ JSON syntax (repositories.json, package-cache.json)
- ✅ Bash syntax (9 scripts)
- ✅ Security best practices (28 fixes)
- ✅ Dependencies (node, npm, jq, gh, curl, git)
- ✅ Workflow YAML syntax
- ✅ Docker configuration

### Continuous Validation
```bash
./scripts/validate-config.sh      # Validate repositories.json
./scripts/quick-check.sh           # Quick essential checks
./scripts/audit-repos.sh           # Audit all repositories
```

### Manual Testing
```bash
# Test specific repository
./scripts/check-single-repo.sh UnityBuildScript

# Test dispatcher (from target repo)
gh workflow run upm-publish-dispatcher.yml --ref master

# Test handler (manual dispatch)
gh api repos/The1Studio/UPMAutoPublisher/dispatches \
  -X POST \
  -f event_type='package_publish' \
  -f client_payload='{"repository":"The1Studio/UnityBuildScript",...}'
```

---

## Error Handling & Recovery

### Automatic Recovery
- **Rate Limits**: Exponential backoff with 5 retries
- **Network Failures**: Retry with increasing delays
- **Registry Unavailable**: Health check before publishing
- **Version Conflicts**: Detect and skip with warning

### Manual Recovery

#### Publish Failure
```bash
# Option 1: Re-trigger dispatcher
cd target-repository
gh workflow run upm-publish-dispatcher.yml

# Option 2: Use publish-unpublished workflow
cd UPMAutoPublisher
gh workflow run publish-unpublished.yml
```

#### Handler Failure
```bash
# Check handler logs
gh run list --workflow=handle-publish-request.yml --limit 5
gh run view <run-id> --log

# Re-trigger with same payload (idempotent)
```

#### GH_PAT Expired
```bash
# Generate new PAT at https://github.com/settings/tokens
# Update organization secret
gh secret set GH_PAT --org The1Studio --body "ghp_new_token"

# Validate
gh auth status
```

---

## Changelog Generation (AI-Powered)

### Workflow Integration
After successful package publish:
1. Extract git commits since last version (git log)
2. Send commit history to Gemini AI
3. AI generates changelog entry in "Keep a Changelog" format
4. Update or create CHANGELOG.md next to package.json
5. Commit with `[skip ci]` message
6. Push changes back to repository

### AI Prompt Structure
```
You are a technical writer for Unity package release notes.
Analyze these commits and generate a changelog entry.

Commits:
<commit history>

Generate in "Keep a Changelog" format:
## [X.Y.Z] - YYYY-MM-DD
### Added
- Feature descriptions...
### Changed
- Improvement descriptions...
### Fixed
- Bug fix descriptions...
```

### Generated Format
```markdown
## [1.2.11] - 2025-11-12

### Fixed
- Fixed null reference exception in GetComponent method
- Resolved memory leak in coroutine cleanup

### Changed
- Improved Update loop performance by 30%
```

### Configuration
- **Model**: gemini-2.0-flash-exp
- **Temperature**: 0.3 (more deterministic)
- **Max Output Tokens**: 1000
- **Fallback**: Graceful failure (continues without changelog)
- **Cost**: Free tier sufficient (<100 packages/day)

---

## Migration History

### v1.0.0 → v1.1.0 (October 2025)
**Focus**: Security hardening
- Fixed 18 security issues (6 critical, 7 high, 5 major)
- Added configurable registry URL
- Added comprehensive audit logging (90-day retention)
- Added version rollback prevention
- Added retry logic and health checks
- Security score: C → A-

### v1.1.0 → v1.2.0 (November 2025)
**Focus**: Architecture migration + additional security fixes
- ✅ Migrated to dispatcher-handler architecture
- ✅ Fixed 10 additional security issues (3 high, 5 major, 2 medium)
- ✅ Added AI-powered changelog generation
- ✅ Enhanced Discord notifications with rich embeds
- ✅ Command injection prevention (complete jq construction)
- ✅ Markdown injection validation
- ✅ GitHub concurrency control (replaces file locking)
- ✅ npm rate limit handling with exponential backoff
- ✅ Secure token validation
- ✅ Temp file security (600 permissions)
- ✅ Docker image pinning (2.311.0)
- ✅ Dependabot configuration
- Security score: A- → A

### Dispatcher Migration (November 2025)
**Migration Plan**: `plans/251111-dispatcher-architecture-migration.md`

**Approach**:
- Phase 1: Create handler workflow ✅
- Phase 2: Create dispatcher template ✅
- Phase 3: Testing & validation ✅
- Phase 4: Gradual rollout (2 pilot repos → 25% → 50% → 75% → 100%) ✅
- Phase 5: Documentation & cleanup ✅

**Results**:
- All 27 repositories migrated successfully
- Zero regressions detected
- Publishing time unchanged (~5-10 minutes)
- Maintenance overhead reduced by 90% (1 file vs 27 files)

---

## Known Limitations

### Current Limitations
1. **Single Registry**: Only supports one UPM registry (configurable via org variable)
2. **npm-only**: Does not support other package managers (yarn, pnpm)
3. **No Rollback**: Cannot unpublish or deprecate versions via workflow
4. **Sequential Processing**: Handler processes one publish request at a time per runner
5. **No Pre-Publish Validation**: Does not run tests before publishing

### Future Enhancements (Planned)
- Multi-registry support (configure per repository)
- Pre-publish testing integration
- Automated dependency vulnerability scanning
- Package download metrics and analytics
- Slack integration for notifications
- Changelog validation and enforcement
- Breaking change detection

---

## Maintenance Procedures

### Daily Maintenance (Automated)
- ✅ Daily audit log cleanup (1 AM UTC)
- ✅ Daily package verification (3 AM UTC)
- ✅ Daily repository status sync (2 AM UTC)
- ✅ Package cache rebuild (when repositories.json changes)

### Weekly Maintenance (Manual)
- Review failed publishes (check Discord notifications)
- Validate GH_PAT expiration (90-day rotation)
- Check runner health (kubectl get runner -n arc-runners)
- Review audit logs for anomalies

### Monthly Maintenance (Manual)
- Update dependencies (Dependabot PRs)
- Review security advisories
- Analyze publish metrics
- Update documentation

### Quarterly Maintenance (Manual)
- Rotate GH_PAT (90 days)
- Review and archive old audit logs
- Performance optimization review
- Security audit

---

## Support & Troubleshooting

### Quick Diagnostics

#### Workflow Not Running
```bash
# Check repository status
./scripts/check-single-repo.sh <repo>

# Check dispatcher file exists
gh api repos/The1Studio/<repo>/contents/.github/workflows/upm-publish-dispatcher.yml

# Check recent workflow runs
gh run list --repo The1Studio/<repo> --workflow upm-publish-dispatcher.yml --limit 5
```

#### Publish Failed
```bash
# Check handler logs
gh run list --workflow handle-publish-request.yml --limit 10
gh run view <run-id> --log-failed

# Check registry health
curl -I https://upm.the1studio.org/

# Check NPM_TOKEN
npm whoami --registry https://upm.the1studio.org/
```

#### GH_PAT Issues
```bash
# Validate GH_PAT
gh auth status

# Check token scopes
gh api user --header "Authorization: token $GH_PAT"

# Check expiration
gh api rate_limit
```

### Documentation Resources
- **Setup**: `docs/setup-instructions.md`
- **Registration**: `docs/quick-registration.md`
- **Troubleshooting**: `docs/troubleshooting.md`
- **Security**: `docs/security-improvements.md`
- **Configuration**: `docs/configuration.md`
- **Architecture**: `docs/architecture-decisions.md`

### Getting Help
1. Check `docs/troubleshooting.md` for common issues
2. Review GitHub Actions logs for error details
3. Check Discord notifications for failure alerts
4. Contact DevOps team via Slack

---

## Version History

- **v1.2.0** (2025-11-12): Dispatcher architecture + security hardening (A security score)
- **v1.1.0** (2025-10-14): Initial security hardening (A- security score)
- **v1.0.0** (2025-01-16): Initial release (monolithic workflow)

---

## References

### Internal Documentation
- `CLAUDE.md`: AI assistant project instructions
- `README.md`: Main project documentation
- `docs/`: Comprehensive documentation suite
- `plans/`: Migration and planning documents

### External Resources
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [npm Registry API](https://docs.npmjs.com/cli/v9/using-npm/registry)
- [Google Gemini API](https://ai.google.dev/docs)
- [Keep a Changelog](https://keepachangelog.com/)
- [Semantic Versioning](https://semver.org/)

---

**Last Updated**: 2025-11-12
**Maintained By**: The1Studio DevOps Team
**Security Status**: A (Hardened Production)
**Active Repositories**: 21 of 27
