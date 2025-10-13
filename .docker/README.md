# GitHub Actions Self-Hosted Runners (Docker)

This directory contains Docker configuration for running self-hosted GitHub Actions runners for The1Studio organization.

## Overview

Creates **3 self-hosted runners** in Docker containers for processing UPM package publishing jobs.

### Why Docker Runners?

✅ **Isolation**: Each runner runs in its own container
✅ **Resource Control**: Memory and CPU limits per runner
✅ **Easy Management**: Start/stop/restart without affecting other services
✅ **Scalability**: Can easily add more runners by duplicating service blocks
✅ **Consistency**: Same environment for all builds
✅ **No Minute Limits**: Unlimited build time on your own hardware

## Quick Start

### 1. Create GitHub Personal Access Token (PAT)

1. Go to https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. **Required scopes**:
   - For **organization runners**: `admin:org`, `repo`
   - For **repository runners**: `repo` only
4. Copy the generated token

### 2. Configure Environment

```bash
cd /mnt/Work/1M/UPM/The1Studio/UPMAutoPublisher/.docker
cp .env.example .env
nano .env  # Add your GitHub PAT
```

Edit `.env`:
```bash
GITHUB_PAT=ghp_your_actual_token_here
```

### 3. Start Runners

```bash
# Start all 3 runners
docker compose -f docker-compose.runners.yml up -d

# Check status
docker compose -f docker-compose.runners.yml ps

# View logs
docker compose -f docker-compose.runners.yml logs -f
```

### 4. Verify Runners in GitHub

**Organization runners**:
- Go to https://github.com/organizations/The1Studio/settings/actions/runners
- You should see: `upm-runner-1`, `upm-runner-2`, `upm-runner-3`

**Repository runners**:
- Go to https://github.com/The1Studio/YourRepo/settings/actions/runners

## Configuration

### Runner Groups

Runners are tagged with:
- **Group**: `upm-publishers`
- **Labels**: `upm`, `nodejs`, `npm`, `docker`

### Resource Limits

Each runner has:
- **Memory**: 4GB
- **CPU**: 2 cores

Adjust in `docker-compose.runners.yml`:
```yaml
mem_limit: 4g  # Change as needed
cpus: 2        # Change as needed
```

### Scaling

To add more runners, duplicate a service block:

```yaml
upm-runner-4:
  image: myoung34/github-runner:latest
  container_name: theone-upm-runner-4
  environment:
    - ORG_NAME=The1Studio
    - ACCESS_TOKEN=${GITHUB_PAT}
    - RUNNER_NAME=upm-runner-4
    - RUNNER_GROUP=upm-publishers
    - LABELS=upm,nodejs,npm,docker
  volumes:
    - upm-runner-4-work:/tmp/runner/work
    - /var/run/docker.sock:/var/run/docker.sock
  restart: unless-stopped
  networks:
    - github-runners
  mem_limit: 4g
  cpus: 2

volumes:
  upm-runner-4-work:
    name: upm-runner-4-work
```

## Using Custom Runners in Workflows

### Update Workflow to Use Self-Hosted Runners

Edit `.github/workflows/publish-upm.yml`:

```yaml
jobs:
  publish:
    # Change from:
    # runs-on: ubuntu-latest

    # To one of these:
    runs-on: self-hosted                    # Any self-hosted runner
    # runs-on: [self-hosted, upm]           # Runner with 'upm' label
    # runs-on: [self-hosted, nodejs, npm]   # Runner with specific labels
```

### Label Matching

Our runners have these labels:
- `self-hosted` (automatic)
- `linux` (automatic)
- `x64` (automatic)
- `upm` (custom)
- `nodejs` (custom)
- `npm` (custom)
- `docker` (custom)

You can target specific runners:
```yaml
runs-on: [self-hosted, upm, nodejs]
```

## Management Commands

### Start/Stop Runners

```bash
# Start all runners
docker compose -f docker-compose.runners.yml up -d

# Stop all runners
docker compose -f docker-compose.runners.yml down

# Restart all runners
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

# Last 50 lines
docker compose -f docker-compose.runners.yml logs --tail=50
```

### Check Status

```bash
# Container status
docker compose -f docker-compose.runners.yml ps

# Resource usage
docker stats theone-upm-runner-1 theone-upm-runner-2 theone-upm-runner-3

# Detailed info
docker inspect theone-upm-runner-1
```

### Update Runners

```bash
# Pull latest image
docker compose -f docker-compose.runners.yml pull

# Restart with new image
docker compose -f docker-compose.runners.yml up -d
```

## Monitoring

### Health Checks

```bash
# Check if runners are connected
docker compose -f docker-compose.runners.yml logs | grep "Connected to GitHub"

# Check for errors
docker compose -f docker-compose.runners.yml logs | grep -i error
```

### GitHub Web UI

Check runner status:
- **Organization**: https://github.com/organizations/The1Studio/settings/actions/runners
- **Repository**: https://github.com/The1Studio/REPO/settings/actions/runners

Green dot = Active and ready
Gray dot = Offline or idle

## Troubleshooting

### Runners Not Appearing in GitHub

**Check logs**:
```bash
docker compose -f docker-compose.runners.yml logs -f upm-runner-1
```

**Common issues**:
1. Invalid GitHub PAT
   - Regenerate token with correct scopes
   - Update `.env` file
2. Wrong organization name
   - Check `ORG_NAME` in docker-compose.yml
3. Runner name conflict
   - Each runner needs unique name

### Authentication Errors

```bash
# Verify token in container
docker exec -it theone-upm-runner-1 env | grep ACCESS_TOKEN
```

If empty, check `.env` file and restart containers.

### Resource Issues

```bash
# Check resource usage
docker stats

# Increase limits in docker-compose.runners.yml
mem_limit: 8g  # Increase from 4g
cpus: 4        # Increase from 2
```

### Runner Stuck or Unresponsive

```bash
# Restart specific runner
docker compose -f docker-compose.runners.yml restart upm-runner-1

# Or recreate it
docker compose -f docker-compose.runners.yml up -d --force-recreate upm-runner-1
```

## Security Considerations

### ⚠️ Important Security Notes

1. **Never use self-hosted runners for public repositories**
   - Anyone can submit malicious PRs
   - Could compromise your machine
   - Only use for private repos or trusted contributors

2. **Protect your GitHub PAT**
   - Store in `.env` file (gitignored)
   - Never commit to repository
   - Rotate token periodically

3. **Docker socket access**
   - Runners have Docker access via `/var/run/docker.sock`
   - Be cautious with workflows that use Docker
   - Consider removing if not needed

4. **Network isolation**
   - Runners are on isolated Docker network
   - Can access host network via Docker socket

### Best Practices

- ✅ Use organization-level runners for multiple repos
- ✅ Set resource limits per runner
- ✅ Monitor runner logs regularly
- ✅ Keep runner image updated
- ✅ Use labels to target specific runners
- ✅ Rotate GitHub PAT annually
- ❌ Don't expose runners to public repos
- ❌ Don't commit `.env` file
- ❌ Don't run as root (container handles this)

## Port Allocation

These runners **do not expose any ports** to the host. They only make outbound connections to GitHub.

No port conflicts with existing services.

## Integration with Port Registry

Add to `/home/tuha/.claude/docker-services.md`:

```markdown
### GitHub Actions Runners (No External Ports)
| Service | Host Port | Container Port | Description |
|---------|-----------|----------------|-------------|
| theone-upm-runner-1 | - | - | GitHub Actions Runner (Outbound only) |
| theone-upm-runner-2 | - | - | GitHub Actions Runner (Outbound only) |
| theone-upm-runner-3 | - | - | GitHub Actions Runner (Outbound only) |
```

## Maintenance

### Regular Tasks

**Weekly**:
- Check runner status in GitHub
- Review logs for errors

**Monthly**:
- Update runner image: `docker compose pull && docker compose up -d`
- Check resource usage patterns

**Annually**:
- Rotate GitHub PAT
- Review runner configuration

### Backup

Runner work directories are in Docker volumes:
- `upm-runner-1-work`
- `upm-runner-2-work`
- `upm-runner-3-work`

These are ephemeral and don't need backup (recreated on each job).

## Removal

To completely remove runners:

```bash
# Stop and remove containers
docker compose -f docker-compose.runners.yml down

# Remove volumes
docker volume rm upm-runner-1-work upm-runner-2-work upm-runner-3-work

# Remove network
docker network rm github-runners-network

# Unregister from GitHub (if needed)
# Go to GitHub organization settings → Actions → Runners → Remove
```

## References

- [myoung34/docker-github-actions-runner](https://github.com/myoung34/docker-github-actions-runner)
- [GitHub Self-Hosted Runners Docs](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

## Support

For issues:
1. Check logs: `docker compose logs -f`
2. Review GitHub runner status
3. Consult troubleshooting section above
4. Check Docker container health: `docker ps`
