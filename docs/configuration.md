# UPM Auto Publisher - Configuration Guide

This guide explains all configurable options for the UPM Auto Publisher system.

## Table of Contents

- [Registry Configuration](#registry-configuration)
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

| Secret | Purpose | How to Obtain |
|--------|---------|---------------|
| `NPM_TOKEN` | Authentication for NPM registry | See [npm-token-setup.md](./npm-token-setup.md) |
| `GITHUB_TOKEN` | Repository registration (auto-provided) | Automatically available in workflows |

### NPM_TOKEN Setup

The `NPM_TOKEN` must have:
- **Scope**: Publish access to your NPM registry
- **Type**: Automation token (not user token)
- **Lifetime**: No expiration (or > 1 year)

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
