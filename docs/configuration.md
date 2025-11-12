# UPM Auto Publisher - Configuration Guide

This guide explains all configurable options for the UPM Auto Publisher system.

## Table of Contents

- [Registry Configuration](#registry-configuration)
- [Discord Notifications](#discord-notifications)
- [Audit Logging](#audit-logging)
- [GitHub Organization Variables](#github-organization-variables)
- [GitHub Organization Secrets](#github-organization-secrets)
- [Workflow Timeouts](#workflow-timeouts)
- [Docker Runner Configuration](#docker-runner-configuration)

---

## Registry Configuration

### Default Registry

By default, the system publishes to `https://upm.the1studio.org/`.

### Custom Registry (Configurable)

You can configure a different registry using GitHub organization variables.

#### Setting Custom Registry

**Option 1: Via GitHub Web UI**
1. Go to https://github.com/organizations/The1Studio/settings/variables/actions
2. Click "New organization variable"
3. Name: `UPM_REGISTRY`
4. Value: `https://your-custom-registry.com/`
5. Click "Add variable"

**Option 2: Via GitHub CLI**
```bash
gh variable set UPM_REGISTRY \
  --body "https://your-custom-registry.com/" \
  --org The1Studio
```

#### Supported Registry Types

- **Verdaccio**: Full support
- **npm registry**: Full support
- **GitHub Packages**: Full support (use `https://npm.pkg.github.com/`)
- **Azure Artifacts**: Full support
- **JFrog Artifactory**: Full support

#### Testing Different Registries

You can test against a staging registry:

```bash
# Set staging registry
gh variable set UPM_REGISTRY \
  --body "https://staging.upm.the1studio.org/" \
  --org The1Studio

# After testing, switch back to production
gh variable set UPM_REGISTRY \
  --body "https://upm.the1studio.org/" \
  --org The1Studio
```

---

## Discord Notifications

### Overview

The UPM Auto Publisher sends Discord webhook notifications for package publishing events, providing real-time updates on successes and failures.

### Notification Types

#### Success Notifications ✅

Sent when packages are successfully published to the registry.

**Includes:**
- 📦 Number of packages published
- ⏭️ Number of packages skipped
- 📁 Repository name with clickable link
- 💬 Commit SHA and message
- 👤 Commit author
- 🎯 Target registry URL
- 🔗 Direct link to workflow run
- ⏰ Timestamp

**Color**: Green (#2ECC71)

#### Failure Notifications ❌

Sent when one or more packages fail to publish.

**Includes:**
- ❌ Number of packages failed
- ✅ Number of packages published (if any)
- ⏭️ Number of packages skipped
- 🚨 List of failed package names
- 📁 Repository name with clickable link
- 💬 Commit SHA and message
- 👤 Commit author
- 🔗 Direct link to workflow logs
- ⏰ Timestamp

**Color**: Red (#E74C3C)

### Setup

#### Prerequisites

You need a Discord webhook URL. To create one:

1. Open Discord and navigate to your server
2. Go to Server Settings → Integrations → Webhooks
3. Click "New Webhook"
4. Configure the webhook:
   - **Name**: `UPM Auto Publisher` (or your choice)
   - **Channel**: Select the channel for notifications (e.g., `#upm-publishes`)
   - **Avatar**: Optional - upload a custom icon
5. Click "Copy Webhook URL"

#### Configuration

**Option 1: Via GitHub CLI**

```bash
gh secret set DISCORD_WEBHOOK_UPM \
  --body "https://discord.com/api/webhooks/your-webhook-url-here" \
  --org The1Studio
```

**Option 2: Via GitHub Web UI**

1. Go to https://github.com/organizations/The1Studio/settings/secrets/actions
2. Click "New organization secret"
3. Name: `DISCORD_WEBHOOK_UPM`
4. Value: Your Discord webhook URL
5. Click "Add secret"

### Behavior

- **Graceful Degradation**: If `DISCORD_WEBHOOK_UPM` is not set, workflows continue normally without sending notifications
- **Non-Blocking**: Notification failures don't stop the workflow
- **Conditional**: Only sends notifications when appropriate:
  - Success: When `published > 0`
  - Failure: When workflow fails OR when `failed > 0`

### Testing

To test Discord notifications:

1. Set up the webhook secret (see [Setup](#setup))
2. Trigger a package publish by bumping a version in any registered repository
3. Check your Discord channel for the notification
4. Verify all information is accurate

**Test command:**

```bash
# In a test repository with UPM package
cd /tmp
gh repo clone The1Studio/UnityBuildScript
cd UnityBuildScript

# Bump version
jq '.version = "1.2.3"' package.json > /tmp/pkg.tmp
mv /tmp/pkg.tmp package.json

# Commit and push (triggers workflow)
git add package.json
git commit -m "test: bump version for Discord notification test"
git push origin master

# Watch workflow run
gh run watch
```

### Troubleshooting

**Issue**: No notifications received
**Solution**:
1. Verify `DISCORD_WEBHOOK_UPM` secret is set correctly
2. Check workflow logs for "⚠️ DISCORD_WEBHOOK_UPM secret not set" message
3. Verify webhook URL is valid in Discord settings
4. Test webhook manually:
   ```bash
   curl -X POST "YOUR_WEBHOOK_URL" \
     -H "Content-Type: application/json" \
     -d '{"content": "Test notification from UPM Auto Publisher"}'
   ```

**Issue**: Notifications sent but formatting is wrong
**Solution**: The workflow uses Discord embeds. Ensure your webhook allows embeds (enabled by default)

**Issue**: Too many notifications
**Solution**: Notifications only send when packages are published or fail. If this is too frequent, consider:
- Batching version bumps
- Using a separate test channel for development repositories
- Creating multiple webhooks for different repository groups

### Security Considerations

⚠️ **Important**: Discord webhook URLs should be treated as secrets:
- ✅ Store in GitHub Secrets (not variables)
- ✅ Never commit webhook URLs to repositories
- ✅ Limit webhook permissions in Discord
- ✅ Use dedicated webhooks per environment (dev/staging/prod)
- ❌ Don't share webhook URLs publicly
- ❌ Don't log webhook URLs in workflow output

### Customization

To customize notification format, edit `.github/workflows/publish-upm.yml`:

**Success notification section** (lines 600-686):
```yaml
- name: Send Discord notification (Success)
  if: success() && env.published > 0
  env:
    DISCORD_WEBHOOK: ${{ secrets.DISCORD_WEBHOOK_UPM }}
  run: |
    # Modify the jq command to customize embed fields
```

**Failure notification section** (lines 688-778):
```yaml
- name: Send Discord notification (Failure)
  if: failure() || (success() && env.failed > 0)
  env:
    DISCORD_WEBHOOK: ${{ secrets.DISCORD_WEBHOOK_UPM }}
  run: |
    # Modify the jq command to customize embed fields
```

### Best Practices

✅ **DO:**
- Create a dedicated Discord channel for UPM notifications
- Test webhook integration before deploying to production
- Use meaningful channel names (e.g., `#upm-publishes`, `#package-releases`)
- Set up Discord role mentions for critical failures (optional)
- Keep webhook URLs secure

❌ **DON'T:**
- Use the same webhook for all environments (use separate webhooks for dev/staging/prod)
- Share webhook URLs in chat or documentation
- Disable notifications entirely (keep for monitoring)
- Ignore failure notifications

### Example Notifications

**Success Example:**

```
✅ UPM Package Published Successfully

📦 Packages Published: 1
⏭️ Packages Skipped: 0

📁 Repository: The1Studio/UnityBuildScript

💬 Commit: a1f0749 chore: bump to 1.0.4

👤 Author: github-actions[bot]

🎯 Registry: https://upm.the1studio.org/

🔗 Workflow Run: View Details
```

**Failure Example:**

```
❌ UPM Package Publish Failed

❌ Packages Failed: 1
✅ Packages Published: 0
⏭️ Packages Skipped: 0

🚨 Failed Packages: com.theone.package@1.0.5

📁 Repository: The1Studio/UnityBuildScript

💬 Commit: abc1234 fix: update dependency

👤 Author: developer-name

🔗 Workflow Run: View Logs
```

---

## Audit Logging

### What is Logged

Every workflow run creates an audit log with:

```json
{
  "timestamp": "2025-10-13T10:30:00Z",
  "workflow_run_id": "12345678",
  "workflow_run_number": "42",
  "repository": "The1Studio/UnityBuildScript",
  "commit_sha": "abc123...",
  "commit_message": "Update package version to 1.2.3",
  "actor": "username",
  "event": "push",
  "ref": "refs/heads/master",
  "published": 1,
  "failed": 0,
  "skipped": 0,
  "registry": "https://upm.the1studio.org/",
  "failed_packages": "none",
  "job_status": "success"
}
```

### Accessing Audit Logs

**Via GitHub Web UI:**
1. Go to repository → Actions
2. Click on a workflow run
3. Scroll down to "Artifacts"
4. Download `audit-log-{run_id}`

**Via GitHub CLI:**
```bash
# List recent artifacts
gh run list --repo The1Studio/UnityBuildScript

# Download specific audit log
gh run download 12345678 \
  --name audit-log-12345678 \
  --repo The1Studio/UnityBuildScript
```

### Audit Log Retention

- **Default**: 90 days
- **Maximum**: 400 days (GitHub limit)
- **Configurable**: Edit `.github/workflows/publish-upm.yml`

To change retention:
```yaml
- name: Upload audit log
  uses: actions/upload-artifact@v4
  with:
    name: audit-log-${{ github.run_id }}
    path: audit-log.json
    retention-days: 180  # Change this value
```

### Querying Audit Logs

Example: Find all failed publishes in the last month

```bash
# Download all recent audit logs
for run_id in $(gh run list --limit 100 --json databaseId --jq '.[].databaseId'); do
  gh run download "$run_id" --name "audit-log-$run_id" --dir ./audit-logs/ 2>/dev/null || true
done

# Find failed publishes
jq 'select(.failed > 0)' ./audit-logs/*/audit-log.json
```

---

## GitHub Organization Variables

### Required Variables

None - all have defaults.

### Optional Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `UPM_REGISTRY` | `https://upm.the1studio.org/` | NPM registry URL for publishing |

### Setting Variables

```bash
# List current variables
gh variable list --org The1Studio

# Set a variable
gh variable set VARIABLE_NAME \
  --body "value" \
  --org The1Studio

# Delete a variable
gh variable delete VARIABLE_NAME --org The1Studio
```

---

## GitHub Organization Secrets

### Required Secrets

| Secret | Purpose | Scope | How to Obtain |
|--------|---------|-------|---------------|
| `NPM_TOKEN` | Authentication for NPM registry | Organization | See [npm-token-setup.md](./npm-token-setup.md) |
| `GH_PAT` | Workflow triggering and PR creation | Organization | See [GH_PAT Setup](#gh_pat-setup) below |

**Note**: `GITHUB_TOKEN` is automatically provided by GitHub Actions but has limitations (cannot trigger other workflows). That's why we need `GH_PAT`.

### Optional Secrets

| Secret | Purpose | Scope | How to Obtain |
|--------|---------|-------|---------------|
| `DISCORD_WEBHOOK_UPM` | Discord webhook URL for publish notifications | Organization | See [Discord Notifications](#discord-notifications) |
| `GEMINI_API_KEY` | AI-powered changelog generation | Organization | See [Gemini API Key](#gemini_api_key-setup) below |

**Note**: If `DISCORD_WEBHOOK_UPM` or `GEMINI_API_KEY` are not set, workflows will continue normally without sending Discord notifications or generating AI changelogs.

### NPM_TOKEN Setup

The `NPM_TOKEN` must have:
- **Scope**: Publish access to your NPM registry
- **Type**: Automation token (not user token)
- **Lifetime**: No expiration (or > 1 year)

### GH_PAT Setup

The `GH_PAT` (GitHub Personal Access Token) is **required** for:
1. **Workflow Triggering**: Commits made by `github-actions[bot]` using `GITHUB_TOKEN` don't trigger other workflows (GitHub security feature to prevent infinite loops)
2. **PR Creation**: Creating PRs in target repositories during automated registration

**Requirements:**
- **Type**: Classic Personal Access Token
- **Scopes**:
  - ✅ `repo` (Full control of private repositories)
  - ✅ `workflow` (Update GitHub Action workflows)
- **Expiration**: Set to 90 days (must be rotated periodically)
- **Owner**: Should be created by organization admin or service account

**How to Create:**

1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Fill in token details:
   - **Note**: `UPMAutoPublisher Workflow Token`
   - **Expiration**: 90 days (recommended)
   - **Scopes**: Select `repo` and `workflow`
4. Click "Generate token"
5. **Copy the token immediately** (you won't be able to see it again)
6. Add to organization secrets:
   ```bash
   gh secret set GH_PAT \
     --body "ghp_your_token_here" \
     --org The1Studio
   ```
   Or via GitHub web UI at https://github.com/organizations/The1Studio/settings/secrets/actions

**Token Validation:**

The workflows automatically validate `GH_PAT` before processing:
```yaml
- name: Validate GH_PAT
  run: |
    if ! gh auth status 2>/dev/null; then
      echo "❌ GH_PAT is invalid or expired"
      exit 1
    fi
```

This validation:
- ✅ Checks if secret is set
- ✅ Verifies authentication is valid
- ✅ Provides clear error messages with rotation instructions if expired

**Set via GitHub CLI:**
```bash
gh secret set NPM_TOKEN \
  --body "your-token-here" \
  --org The1Studio
```

**Set via GitHub Web UI:**
1. Go to https://github.com/organizations/The1Studio/settings/secrets/actions
2. Click "New organization secret"
3. Name: `NPM_TOKEN`
4. Value: [paste your token]
5. Click "Add secret"

### Token Rotation

#### NPM_TOKEN Rotation

**Recommended**: Rotate `NPM_TOKEN` annually

```bash
# 1. Generate new token from your registry
# 2. Update GitHub secret
gh secret set NPM_TOKEN \
  --body "new-token-here" \
  --org The1Studio

# 3. Verify with a test publish
# 4. Revoke old token from registry
```

#### GH_PAT Rotation

**Required**: Rotate `GH_PAT` every 90 days (or at expiration)

```bash
# 1. Create new PAT at https://github.com/settings/tokens
#    - Scopes: repo, workflow
#    - Expiration: 90 days

# 2. Update GitHub secret
gh secret set GH_PAT \
  --body "ghp_new_token_here" \
  --org The1Studio

# 3. Verify with test workflow run
gh workflow run manual-register-repo.yml \
  --repo The1Studio/UPMAutoPublisher \
  --field repo_url=https://github.com/The1Studio/TestRepo

# 4. Delete old PAT at https://github.com/settings/tokens
```

**Set Reminder:**
- Add a calendar reminder for 80 days from creation
- GitHub will email warnings before expiration
- Workflows will fail with clear error message if GH_PAT expires

### GEMINI_API_KEY Setup

The `GEMINI_API_KEY` (optional) enables AI-powered automatic changelog generation using Google Gemini API.

**Requirements:**
- **Type**: API key from Google AI Studio
- **Model**: gemini-2.0-flash-exp (fast, cost-effective)
- **Usage**: Analyzes git commits and generates Keep a Changelog format entries
- **Fallback**: If not set or API fails, packages still publish (no changelog generated or basic fallback used)

**How to Create:**

1. Go to https://aistudio.google.com/app/apikey
2. Click "Create API key"
3. Select project or create new one
4. Copy the API key (starts with `AIza...`)
5. Add to organization secrets:
   ```bash
   gh secret set GEMINI_API_KEY \
     --body "AIza_your_key_here" \
     --org The1Studio
   ```
   Or via GitHub web UI at https://github.com/organizations/The1Studio/settings/secrets/actions

**How It Works:**
- Automatically triggers after packages are successfully published
- Downloads `generate-changelog.sh` script from UPMAutoPublisher repository
- For each published package:
  - Analyzes git commits since last version in package directory
  - Sends commit history to Gemini AI with structured prompt
  - Generates human-readable changelog in Keep a Changelog format
  - Updates or creates CHANGELOG.md next to package.json
- Commits all changelog changes with `[skip ci]` message
- Pushes changes back to source repository using `GH_PAT`
- If API fails, falls back to basic changelog format or skips gracefully
- Uses `continue-on-error: true` to never fail the workflow

**API Limits (Free Tier):**
- 15 requests per minute
- 1,500 requests per day
- 1 million tokens per day
- ~500 tokens per changelog (~0.05% of daily limit)

**Cost:**
- Free tier sufficient for typical usage (<100 packages/day)
- If exceeded: automatic fallback, no publishing blocked

**Security:**
- Stored as organization secret (encrypted at rest)
- GitHub automatically masks in logs
- Can be rotated anytime without workflow changes

---

## Workflow Timeouts

### Current Timeouts

```yaml
# Job-level timeout
timeout-minutes: 20

# Step-level timeout
timeout-minutes: 15
```

### Why Timeouts?

- Prevents hung workflows from consuming runner minutes
- Detects network issues early
- Limits exposure to denial-of-service

### Adjusting Timeouts

Edit `.github/workflows/publish-upm.yml`:

```yaml
jobs:
  publish:
    runs-on: ubuntu-latest
    timeout-minutes: 30  # Increase if needed

    steps:
      - name: Detect and publish changed packages
        timeout-minutes: 25  # Must be less than job timeout
```

### Timeout Guidelines

| Repository Type | Recommended Job Timeout | Step Timeout |
|-----------------|------------------------|--------------|
| Single package | 10 minutes | 8 minutes |
| Multiple packages (2-5) | 20 minutes | 15 minutes |
| Large monorepo (6+) | 30 minutes | 25 minutes |

---

## Docker Runner Configuration

### Environment Variables

The self-hosted Docker runners support these environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `ORG_NAME` | `The1Studio` | GitHub organization name |
| `RUNNER_NAME` | `upm-runner-1` | Unique runner identifier |
| `RUNNER_GROUP` | `upm-publishers` | Runner group for organization |
| `LABELS` | `upm,nodejs,npm` | Custom labels for targeting |
| `RUNNER_SCOPE` | `org` | Scope: `org` or `repo` |
| `DISABLE_AUTO_UPDATE` | `true` | Prevent automatic runner updates |

### Resource Limits

Default per runner:
```yaml
mem_limit: 4g
cpus: 2
```

**Sizing Guidelines:**
- **Light**: 2GB / 1 CPU (single package repos)
- **Standard**: 4GB / 2 CPU (most use cases) ← Current
- **Heavy**: 8GB / 4 CPU (large monorepos)

See [Docker README](./.docker/README.md) for detailed configuration.

### Secrets Configuration

Runners use Docker secrets instead of environment variables:

```yaml
secrets:
  github_pat:
    file: ./.secrets/github_pat
```

See [Docker Setup Guide](../.docker/README.md#setup) for complete instructions.

---

## Advanced Configuration

### Custom Workflow Triggers

By default, workflows trigger on:
```yaml
on:
  push:
    branches: [master, main]
    paths: ['**/package.json']
```

**Add manual trigger:**
```yaml
on:
  push:
    branches: [master, main]
    paths: ['**/package.json']
  workflow_dispatch:  # Add this
```

**Trigger on tags:**
```yaml
on:
  push:
    tags: ['v*']
  paths: ['**/package.json']
```

### Multi-Registry Publishing

To publish to multiple registries, duplicate the step:

```yaml
- name: Publish to primary registry
  env:
    UPM_REGISTRY: https://upm.the1studio.org/
  run: |
    # ... publish logic ...

- name: Publish to backup registry
  env:
    UPM_REGISTRY: https://backup.upm.the1studio.org/
  run: |
    # ... publish logic ...
```

### Custom Package Validation

Add custom validation rules in workflow:

```yaml
# After package name extraction
if [[ ! "$package_name" =~ ^com\.theone\. ]]; then
  echo "❌ Invalid package name: $package_name"
  exit 1
fi

# Add your custom rules here
if [[ "$package_name" == "com.theone.restricted" ]]; then
  echo "❌ This package requires manual approval"
  exit 1
fi
```

---

## Troubleshooting Configuration

### Verify Current Configuration

```bash
# Check organization variables
gh variable list --org The1Studio

# Check organization secrets (names only, not values)
gh secret list --org The1Studio

# Check runner status
gh api /orgs/The1Studio/actions/runners
```

### Common Issues

**Issue**: Packages publishing to wrong registry
**Solution**: Check `UPM_REGISTRY` variable and `publishConfig.registry` in package.json

**Issue**: Authentication failures
**Solution**: Verify `NPM_TOKEN` secret is set and valid

**Issue**: Workflow timeouts
**Solution**: Increase timeout values or investigate network issues

---

## Configuration Best Practices

✅ **DO:**
- Use organization-level secrets and variables
- Set reasonable timeout values
- Rotate tokens annually
- Keep audit logs for compliance
- Test configuration changes in a staging environment

❌ **DON'T:**
- Hardcode registry URLs in package.json
- Use personal access tokens for automation
- Set extremely long timeouts (> 30 min)
- Commit secrets to repository
- Skip token rotation

---

## See Also

- [Setup Instructions](./setup-instructions.md)
- [NPM Token Setup](./npm-token-setup.md)
- [Troubleshooting Guide](./troubleshooting.md)
- [Docker Runner Setup](../.docker/README.md)
- [Architecture Decisions](./architecture-decisions.md)

---

**Last Updated**: 2025-10-13
**Version**: 1.1.0
