# Quick Repository Registration Guide

**🎯 Goal**: Register a new repository for UPM auto-publishing in under 30 seconds.

## TL;DR - The Fast Way (Webhook-Only Architecture)

```bash
# 1. Add repo to config/repositories.json with status: "active"
# 2. Commit and push
# 3. Done! Cloudflare webhook handles everything
```

**That's it!** No workflow files needed in target repositories. The organization webhook detects package.json changes and publishes automatically.

---

## Step-by-Step Registration

### Step 1: Add Repository to Registry (20 seconds)

Edit `config/repositories.json` in the UPMAutoPublisher repo:

```json
{
  "repositories": [
    {
      "url": "https://github.com/The1Studio/YourNewRepo",
      "status": "active"
    }
  ]
}
```

**Note:** Set `status: "active"` immediately. The Cloudflare webhook is already configured organization-wide.

### About Package Auto-Discovery

**You don't need to list packages!** The webhook automatically:
- Detects all `package.json` files in your repository
- Publishes each package when its version changes
- Handles single-package and multi-package repos the same way

The only configuration needed is the repository URL and status.

**Multi-package repositories work automatically** - whether you have one package or ten, the workflow finds them all via `git diff` when you push changes.

### Step 2: Commit and Push (10 seconds)

```bash
cd /mnt/Work/1M/1.OneTools/UPM/The1Studio/UPMAutoPublisher

git add config/repositories.json
git commit -m "Register YourNewRepo for UPM auto-publishing"
git push origin master
```

### Step 3: Done! 🎉

**That's it!** The Cloudflare webhook is now monitoring your repository.

**What happens next:**
1. When you bump a package version in YourNewRepo and push
2. Cloudflare webhook detects the package.json change (< 1 second)
3. Triggers `handle-publish-request.yml` workflow automatically
4. Package is published to `upm.the1studio.org`
5. AI-generated changelog is committed back to your repo
6. Discord notification sent with results

**No workflow files needed in your target repository!**

---

## How to Publish a Package

After registration, publishing is automatic:

```bash
cd /path/to/YourNewRepo

# 1. Update package version
jq '.version = "1.0.1"' package.json > tmp.json && mv tmp.json package.json

# 2. Commit and push
git add package.json
git commit -m "Bump version to 1.0.1"
git push origin master

# 3. Wait ~30 seconds for automatic publishing
# Package is automatically published to upm.the1studio.org!
```

**Verify published:**
```bash
npm view com.theone.yourpackage@1.0.1 --registry https://upm.the1studio.org/
```

---

## Complete Example

```json
// config/repositories.json
{
  "repositories": [
    {
      "url": "https://github.com/The1Studio/UnityBuildScript",
      "status": "active"
    },
    {
      "url": "https://github.com/The1Studio/TheOne.ProjectSetup",
      "status": "active"
    }
  ]
}
```

**That's it!** The webhook automatically discovers all packages in each repository.

---

## Repository Status Values

| Status | Meaning | Action |
|--------|---------|--------|
| `"active"` | **Webhook monitoring enabled** | ✅ Publishes on version changes |
| `"disabled"` | **Temporarily disabled** | ⏭️ Webhook ignores repository |

---

## Package Configuration Requirements

Each target repository **must** have `package.json` with required Unity package fields:

### ✅ Minimal Required Configuration

```json
{
  "name": "com.theone.yourpackage",
  "version": "1.0.0",
  "displayName": "Your Package",
  "description": "Package description",
  "unity": "2022.3"
}
```

**Registry Configuration**: The workflow automatically publishes to the configured registry using the `--registry` flag. You do **NOT** need to add `publishConfig.registry` to your package.json.

**How it works:**
- Workflow uses `UPM_REGISTRY` organization variable (default: `https://upm.the1studio.org/`)
- Publishing command: `npm publish --registry "$UPM_REGISTRY"`
- This approach allows centralized registry management without modifying each package.json

### ❌ Missing Required Fields

```json
{
  "version": "1.0.0"
  // ❌ Missing "name" field - workflow will skip publishing
}
```

**Ensure required fields are present:**
- `name`: Package identifier (e.g., `com.theone.yourpackage`)
- `version`: Semantic version (e.g., `1.0.0`)
- `displayName`: Human-readable name (recommended)
- `unity`: Minimum Unity version (recommended)

---

## Troubleshooting

### Package Not Publishing

**Check these:**

1. **Repository registered with status "active"?**
   ```bash
   jq '.[] | select(.url | contains("YourRepo"))' config/repositories.json
   ```

2. **Cloudflare webhook working?**
   - Check webhook logs at Cloudflare dashboard
   - Recent push should appear in logs

3. **Workflow triggered?**
   ```bash
   gh run list --repo The1Studio/UPMAutoPublisher --workflow handle-publish-request.yml --limit 5
   ```

4. **Package.json has required fields?**
   ```bash
   jq '{name, version}' /path/to/package.json
   ```

### Webhook Not Triggering

If pushes aren't triggering workflows:

1. **Check repository is registered:**
   ```bash
   jq '.[] | .url' config/repositories.json
   ```

2. **Verify status is "active":**
   ```bash
   jq '.[] | select(.status == "active") | .url' config/repositories.json
   ```

3. **Test manual trigger:**
   ```bash
   curl -X POST \
     -H "Authorization: Bearer $(gh auth token)" \
     https://api.github.com/repos/The1Studio/UPMAutoPublisher/dispatches \
     -d '{
       "event_type": "package_publish",
       "client_payload": {
         "repository": "The1Studio/YourRepo",
         "commit_sha": "'$(git rev-parse HEAD)'",
         "branch": "master"
       }
     }'
   ```

---

## Multi-Repository Registration

Register multiple repos at once:

```json
{
  "repositories": [
    {
      "url": "https://github.com/The1Studio/Repo1",
      "status": "active"
    },
    {
      "url": "https://github.com/The1Studio/Repo2",
      "status": "active"
    },
    {
      "url": "https://github.com/The1Studio/Repo3",
      "status": "active"
    }
  ]
}
```

**Commit once**, all repos are immediately monitored by the webhook!

---

## Benefits of Webhook-Only Architecture

### Before (Per-Repo Workflows)
1. Add repo to config
2. Wait for PR creation automation
3. Review and merge PR in target repo
4. Update status to active
5. Test publishing

**Time**: ~5 minutes per repo

### After (Webhook-Only)
1. Add repo to JSON with `status: "active"`
2. Commit and push

**Time**: ~30 seconds per repo

**Time saved**: ~4.5 minutes per repo
**For 10 repos**: Saves ~45 minutes!

---

## Security Notes

### Organization Secrets Required

- **NPM_TOKEN**: Can publish to `upm.the1studio.org`
- **GH_PAT**: Can trigger workflows and commit changelogs
- **GEMINI_API_KEY** (optional): Enables AI changelog generation
- **WEBHOOK_SECRET**: Secures Cloudflare webhook

All should already be configured at organization level.

---

## Workflow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Add repo to repositories.json with status: "active"     │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Commit and push to UPMAutoPublisher master              │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Done! Webhook is now monitoring the repository          │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ When package version bumped:                                │
│  1. Push to target repo                                     │
│  2. GitHub webhook → Cloudflare Worker (< 1s)               │
│  3. Worker triggers handle-publish-request.yml              │
│  4. Workflow publishes package                              │
│  5. AI generates changelog (if GEMINI_API_KEY set)          │
│  6. Discord notification sent                               │
└─────────────────────────────────────────────────────────────┘
```

---

## FAQ

### Q: Do I need to add any files to my repository?
**A:** No! The webhook monitors your repo without any workflow files.

### Q: Can I register private repositories?
**A:** Yes! Webhook works with both public and private repos in The1Studio organization.

### Q: What happens if I add multiple repos at once?
**A:** All are monitored immediately after you push the config change.

### Q: Can I test without affecting real packages?
**A:** Yes! Use a test repository with a test package name.

### Q: What if the webhook fails?
**A:** There's a fallback polling system (`monitor-all-repos.yml`) that runs every 5 minutes.

### Q: How do I temporarily disable a repository?
**A:** Change status to `"disabled"` in repositories.json.

---

## Checklist: Ready to Register?

Before registering a new repo, verify:

- [ ] Repository exists in The1Studio organization
- [ ] Package has valid `package.json` file
- [ ] `package.json` has `name` starting with `com.theone.`
- [ ] `package.json` has `version` field
- [ ] You have write access to UPMAutoPublisher repo
- [ ] Organization has `NPM_TOKEN` secret configured
- [ ] Organization has `GH_PAT` secret configured
- [ ] Organization has `WEBHOOK_SECRET` configured

---

## Related Documentation

- [Main README](../README.md)
- [Architecture Decisions](architecture-decisions.md)
- [Troubleshooting](troubleshooting.md)
- [Configuration Guide](configuration.md)

---

**Need help?** Check workflow logs or create an issue in UPMAutoPublisher repository.
