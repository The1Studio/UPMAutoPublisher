# Self-Hosted GitHub Actions Runners

Guide for using self-hosted Docker runners instead of GitHub-hosted runners for UPM auto-publishing.

## Overview

This project can use **self-hosted runners** running in Docker containers on your own infrastructure instead of GitHub's hosted runners.

### Benefits

✅ **Unlimited Minutes**: No GitHub Actions minute limits
✅ **Faster Builds**: Pre-cached dependencies, faster network
✅ **More Control**: Custom environment, tools, and configurations
✅ **Resource Management**: Dedicated CPU and memory per runner
✅ **Cost Savings**: No per-minute charges for private repos
✅ **Better Performance**: Local network access to registry

### Trade-offs

⚠️ **Maintenance**: Need to maintain runner infrastructure
⚠️ **Security**: Your responsibility to secure runners
⚠️ **Availability**: Need to ensure runners are online
⚠️ **Updates**: Manual image updates required

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- GitHub Personal Access Token (PAT) with appropriate scopes
- Access to The1Studio GitHub organization

### 1. Generate GitHub Personal Access Token

1. Go to https://github.com/settings/tokens
2. Click **"Generate new token (classic)"**
3. Select scopes:
   - For **organization runners**: `admin:org`, `repo`
   - For **repository runners**: `repo` only
4. Generate and copy the token

### 2. Configure Environment

```bash
cd /mnt/Work/1M/UPM/The1Studio/UPMAutoPublisher/.docker
cp .env.example .env
nano .env
```

Add your GitHub PAT:
```bash
GITHUB_PAT=ghp_your_actual_token_here
```

### 3. Start Runners

```bash
# Start all 3 runners
docker compose -f docker-compose.runners.yml up -d

# Check status
docker compose -f docker-compose.runners.yml ps

# View logs to confirm connection
docker compose -f docker-compose.runners.yml logs -f
```

Look for: `"Connected to GitHub"`

### 4. Verify in GitHub

**Organization runners**:
https://github.com/organizations/The1Studio/settings/actions/runners

You should see:
- ✅ upm-runner-1 (Idle)
- ✅ upm-runner-2 (Idle)
- ✅ upm-runner-3 (Idle)

### 5. Update Workflow to Use Self-Hosted Runners

Edit `.github/workflows/publish-upm.yml`:

```yaml
jobs:
  publish:
    # Change this line:
    runs-on: ubuntu-latest

    # To this:
    runs-on: [self-hosted, upm]

    # Or just:
    # runs-on: self-hosted
```

Commit and push the change.

### 6. Test

Make a version bump in any package.json and push:

```bash
# Update version
sed -i 's/"version": "1.2.10"/"version": "1.2.11"/' Assets/BuildScripts/package.json

# Commit and push
git add Assets/BuildScripts/package.json
git commit -m "Test self-hosted runner: bump to 1.2.11"
git push
```

Watch the workflow run on your self-hosted runner!

## Runner Configuration

### Included Runners

The Docker Compose setup includes **3 runners**:

| Runner Name | Memory | CPU | Labels |
|-------------|--------|-----|--------|
| upm-runner-1 | 4GB | 2 cores | self-hosted, linux, x64, upm, nodejs, npm, docker |
| upm-runner-2 | 4GB | 2 cores | self-hosted, linux, x64, upm, nodejs, npm, docker |
| upm-runner-3 | 4GB | 2 cores | self-hosted, linux, x64, upm, nodejs, npm, docker |

### Runner Labels

You can target runners using labels:

```yaml
# Any self-hosted runner
runs-on: self-hosted

# Runner with 'upm' label
runs-on: [self-hosted, upm]

# Runner with multiple specific labels
runs-on: [self-hosted, nodejs, npm]
```

### Resource Limits

Each runner is limited to:
- **Memory**: 4GB
- **CPU**: 2 cores

Adjust in `docker-compose.runners.yml`:
```yaml
mem_limit: 4g
cpus: 2
```

### Scaling

On a 128GB RAM machine, you can run many more runners:

**Conservative** (8GB per runner): Up to 16 runners
**Moderate** (4GB per runner): Up to 32 runners
**Aggressive** (2GB per runner): Up to 64 runners

To add more runners, duplicate service blocks in `docker-compose.runners.yml`.

## Management

### Start/Stop Runners

```bash
cd /mnt/Work/1M/UPM/The1Studio/UPMAutoPublisher/.docker

# Start all
docker compose -f docker-compose.runners.yml up -d

# Stop all
docker compose -f docker-compose.runners.yml down

# Restart all
docker compose -f docker-compose.runners.yml restart

# Start specific runner
docker compose -f docker-compose.runners.yml up -d upm-runner-1
```

### View Logs

```bash
# All runners
docker compose -f docker-compose.runners.yml logs -f

# Specific runner
docker compose -f docker-compose.runners.yml logs -f upm-runner-1

# Last 100 lines
docker compose -f docker-compose.runners.yml logs --tail=100
```

### Monitor Status

```bash
# Container status
docker compose -f docker-compose.runners.yml ps

# Resource usage (real-time)
docker stats theone-upm-runner-1 theone-upm-runner-2 theone-upm-runner-3

# GitHub UI
# https://github.com/organizations/The1Studio/settings/actions/runners
```

### Update Runners

```bash
# Pull latest runner image
docker compose -f docker-compose.runners.yml pull

# Restart with new image
docker compose -f docker-compose.runners.yml up -d
```

## Architecture

### Organization vs Repository Runners

**Organization-level** (recommended):
- Available to all repos in The1Studio
- Single configuration for entire org
- Easier to manage
- Requires `admin:org` token scope

**Repository-level**:
- Available to single repo only
- Per-repo configuration
- More granular control
- Only requires `repo` token scope

Current setup uses **organization-level** runners.

### Runner Groups

Runners are organized in group: `upm-publishers`

This allows:
- Group-level access control
- Targeting specific runner groups
- Better organization

### Docker-in-Docker

Runners have access to Docker via socket mount:
```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

This allows workflows to:
- Build Docker images
- Run containers
- Use docker-compose

⚠️ **Security note**: This grants significant privileges. Remove if not needed.

### Network Isolation

Runners run on isolated network: `github-runners-network`

They can:
- ✅ Make outbound connections (GitHub, npm registry)
- ✅ Access Docker host via socket
- ❌ Accept inbound connections (no exposed ports)

## Workflow Migration

### From GitHub-Hosted to Self-Hosted

**Before**:
```yaml
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      # ...
```

**After**:
```yaml
jobs:
  publish:
    runs-on: [self-hosted, upm]  # Only change needed
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      # ... rest stays the same
```

### Compatibility

Most GitHub Actions work identically on self-hosted runners:
- ✅ `actions/checkout`
- ✅ `actions/setup-node`
- ✅ `actions/cache`
- ✅ npm commands
- ✅ Git operations

**Differences**:
- Tool versions may differ (runner's Ubuntu vs GitHub's)
- Network access patterns
- File system paths

## Troubleshooting

### Runners Not Appearing in GitHub

**Check logs**:
```bash
docker compose -f docker-compose.runners.yml logs | grep -i error
docker compose -f docker-compose.runners.yml logs | grep "Connected"
```

**Common causes**:
1. Invalid GitHub PAT
   - Regenerate with correct scopes
   - Update `.env`
   - Restart containers
2. Wrong organization name
   - Check `ORG_NAME` in docker-compose.yml
3. Runner name already exists
   - Remove old runner from GitHub
   - Or use different runner name

### Runner Offline

**Check container status**:
```bash
docker ps | grep upm-runner
```

**Restart runner**:
```bash
docker compose -f docker-compose.runners.yml restart upm-runner-1
```

### Workflow Stuck on "Waiting for runner"

**Causes**:
1. No runners available (all busy)
   - Add more runners
   - Wait for current jobs to finish
2. Label mismatch
   - Check workflow `runs-on` labels match runner labels
3. All runners offline
   - Check runner status in GitHub
   - Restart runner containers

### Authentication Errors During Job

**NPM token issues**:
- Verify `NPM_TOKEN` secret exists in repository/organization
- Check secret is accessible (permissions)

**GitHub token issues**:
- Default `GITHUB_TOKEN` works on self-hosted runners
- Check workflow permissions if needed

### Resource Exhaustion

**Symptoms**:
- Runners slow or unresponsive
- OOM (Out of Memory) errors
- Job timeouts

**Solutions**:
```bash
# Check resource usage
docker stats

# Increase limits in docker-compose.runners.yml
mem_limit: 8g  # Increase from 4g
cpus: 4        # Increase from 2

# Restart runners
docker compose -f docker-compose.runners.yml up -d
```

## Security Best Practices

### ⚠️ Critical Security Rules

1. **NEVER use self-hosted runners for public repositories**
   - Anyone can fork and submit malicious PRs
   - Could compromise your infrastructure
   - Only use for private repos or trusted contributors

2. **Protect GitHub PAT**
   - Store in `.env` (gitignored)
   - Never commit to repository
   - Rotate annually
   - Use minimal required scopes

3. **Review workflow changes**
   - Require PR reviews for workflow changes
   - Use branch protection on `.github/workflows/`
   - Monitor workflow runs

4. **Limit Docker access**
   - Consider removing Docker socket mount if not needed
   - Use Docker-in-Docker alternatives if possible

5. **Network security**
   - Runners should only make outbound connections
   - No exposed ports
   - Use firewall rules if needed

### GitHub Organization Settings

Recommended settings:

1. **Actions → General**:
   - Require approval for first-time contributors
   - Require approval for all outside collaborators

2. **Actions → Runner groups**:
   - Limit `upm-publishers` group to specific repos
   - Set group visibility

3. **Branch protection**:
   - Require reviews for workflow changes
   - Restrict who can modify `.github/workflows/`

## Monitoring and Maintenance

### Health Checks

**Daily**:
```bash
# Quick status check
docker compose -f docker-compose.runners.yml ps
```

**Weekly**:
```bash
# Review logs for errors
docker compose -f docker-compose.runners.yml logs --tail=500 | grep -i error

# Check resource usage patterns
docker stats --no-stream theone-upm-runner-*
```

**Monthly**:
```bash
# Update runner image
docker compose -f docker-compose.runners.yml pull
docker compose -f docker-compose.runners.yml up -d

# Clean up old images
docker image prune -f
```

### Metrics to Monitor

- Runner online/offline status
- Job success/failure rates
- Average job duration
- Resource usage (CPU, memory)
- Container restarts

### Alerting

Consider setting up alerts for:
- All runners offline
- High failure rate
- Resource exhaustion
- Container crashes

## Cost Analysis

### GitHub-Hosted Runners

**Private repositories**:
- 2000 free minutes/month (Free plan)
- 3000 minutes/month (Pro plan)
- $0.008/minute after limit

**Example**: 100 builds/day × 2 minutes = 6000 minutes/month
- Free plan: $32/month overage
- Pro plan: $24/month overage

### Self-Hosted Runners

**Costs**:
- Hardware/server: $0 (using existing machine)
- Electricity: ~$5-10/month per server
- Maintenance time: ~1 hour/month

**ROI**: Saves $20-30/month for moderate usage
Pays for itself in 1 month if running >3000 minutes/month

## Migration Checklist

Ready to migrate? Follow this checklist:

- [ ] Generate GitHub PAT with correct scopes
- [ ] Configure `.docker/.env` with PAT
- [ ] Start runner containers
- [ ] Verify runners appear in GitHub
- [ ] Update workflow to use `runs-on: [self-hosted, upm]`
- [ ] Test with dummy version bump
- [ ] Monitor first real publish
- [ ] Document any issues encountered
- [ ] Update team documentation
- [ ] Set up monitoring/alerts (optional)
- [ ] Schedule regular maintenance

## Comparison: GitHub-Hosted vs Self-Hosted

| Feature | GitHub-Hosted | Self-Hosted |
|---------|--------------|-------------|
| **Cost** | Per-minute charges | Electricity + maintenance |
| **Setup** | Zero setup | Initial Docker setup |
| **Maintenance** | Zero | Image updates, monitoring |
| **Performance** | Good | Potentially faster |
| **Caching** | Limited | Full control |
| **Minutes** | Limited (free tier) | Unlimited |
| **Security** | GitHub's responsibility | Your responsibility |
| **Availability** | 99.9% SLA | Depends on infrastructure |
| **Scalability** | Auto-scales | Manual scaling |
| **Environment** | Standard Ubuntu | Custom configuration |

## Conclusion

Self-hosted runners are recommended when:
- ✅ Running many builds (>3000 min/month)
- ✅ Need custom environment
- ✅ Want better performance
- ✅ Have infrastructure available
- ✅ Can maintain runners

Stick with GitHub-hosted when:
- ⏭️ Low build volume
- ⏭️ Don't want maintenance overhead
- ⏭️ Need guaranteed availability
- ⏭️ Public repositories

## References

- [Docker Runner Setup](.docker/README.md)
- [GitHub Self-Hosted Runners Docs](https://docs.github.com/en/actions/hosting-your-own-runners)
- [myoung34/docker-github-actions-runner](https://github.com/myoung34/docker-github-actions-runner)
- [Security Hardening Guide](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#hardening-for-self-hosted-runners)

## Support

For issues or questions:
1. Check [.docker/README.md](.docker/README.md) troubleshooting
2. Review GitHub runner logs
3. Check container health: `docker ps`
4. Consult GitHub Actions documentation
