# NPM Token Setup Guide

Complete guide for creating and configuring NPM authentication token for UPM auto-publishing.

## Overview

The auto-publishing workflow requires an NPM authentication token to publish packages to `upm.the1studio.org`. This token should be:

- Created once for the organization
- Stored as a GitHub organization secret
- Available to all repositories in The1Studio organization
- Long-lived (no expiration) for continuous operation

## One-Time Setup

### Step 1: Generate NPM Token

**Prerequisites:**
- Access to a machine with npm configured for `upm.the1studio.org`
- Admin credentials for the UPM registry

**Commands:**

```bash
# 1. Verify you're authenticated
npm whoami --registry https://upm.the1studio.org/
# Should output: admin (or your username)

# 2. Create a new automation token (no expiration)
npm token create --read-only=false --registry https://upm.the1studio.org/

# Output will show:
# ┌────────────────┬──────────────────────────────────────┐
# │ token          │ npm_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx │
# │ cidr_whitelist │                                       │
# │ readonly       │ false                                 │
# │ created        │ 2025-01-16T10:00:00.000Z             │
# └────────────────┴──────────────────────────────────────┘
```

**Important:**
- Copy the token immediately (you won't see it again)
- Token format: `npm_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
- Save it securely (we'll add it to GitHub next)

### Step 2: Add Token to GitHub Organization Secrets

1. **Navigate to Organization Settings:**
   - Go to https://github.com/organizations/The1Studio/settings/secrets/actions
   - Or: GitHub → The1Studio (org) → Settings → Secrets and variables → Actions

2. **Create New Secret:**
   - Click "New organization secret"
   - Name: `NPM_TOKEN`
   - Value: Paste the token from Step 1 (e.g., `npm_xxxxx...`)
   - Repository access: Select "All repositories" or specific repos

3. **Save:**
   - Click "Add secret"

### Step 3: Verify Setup

Test that repositories can access the token:

```bash
# In any repository with the workflow
gh secret list --org The1Studio

# Should show:
# NPM_TOKEN    Updated 2025-01-16
```

Or check in a workflow run:

```yaml
- name: Test token access
  run: |
    if [ -z "${{ secrets.NPM_TOKEN }}" ]; then
      echo "❌ NPM_TOKEN not accessible"
      exit 1
    else
      echo "✅ NPM_TOKEN is accessible"
    fi
```

## Token Management

### Viewing Existing Tokens

```bash
# List all tokens
npm token list --registry https://upm.the1studio.org/

# Output:
# ┌──────────┬─────────┬────────────┬──────────┬────────────────┐
# │ id       │ token   │ created    │ readonly │ CIDR whitelist │
# ├──────────┼─────────┼────────────┼──────────┼────────────────┤
# │ abcd1234 │ npm_... │ 2025-01-16 │ no       │                │
# └──────────┴─────────┴────────────┴──────────┴────────────────┘
```

### Revoking Old Tokens

If you need to rotate tokens or revoke compromised ones:

```bash
# List tokens to get the token ID
npm token list --registry https://upm.the1studio.org/

# Revoke by ID
npm token revoke <token-id> --registry https://upm.the1studio.org/

# Example:
npm token revoke abcd1234 --registry https://upm.the1studio.org/
```

After revoking:
1. Create a new token (Step 1)
2. Update GitHub organization secret (Step 2)

### Token Rotation Best Practices

**Recommended schedule:** Rotate tokens annually or when:
- Team member with token access leaves
- Token may have been exposed
- Security audit requires it

**Process:**
1. Create new token
2. Update GitHub secret with new token
3. Verify workflows still work
4. Revoke old token
5. Document rotation in security log

## Security Considerations

### Token Permissions

The token has **write** permissions (`readonly: false`) which allows:
- ✅ Publishing packages
- ✅ Updating package metadata
- ❌ Deleting packages (requires additional permissions)

### Access Control

**GitHub Organization Secret Settings:**
- Limit access to specific repositories if needed
- Review "Secret access" logs periodically
- Enable "Required approval for workflows" if desired

**NPM Registry Level:**
- Token is scoped to `upm.the1studio.org` only
- Cannot publish to public npm registry
- Cannot access other registries

### If Token is Compromised

**Immediate actions:**

1. **Revoke the token:**
   ```bash
   npm token revoke <token-id> --registry https://upm.the1studio.org/
   ```

2. **Check for unauthorized publishes:**
   ```bash
   # List recent publishes
   npm view com.theone.* --registry https://upm.the1studio.org/

   # Check specific package versions
   npm view com.theone.package versions --registry https://upm.the1studio.org/
   ```

3. **Create and deploy new token:**
   - Follow Step 1 and 2 above
   - Workflows will automatically use new token

4. **Review security:**
   - Check GitHub Actions logs for suspicious activity
   - Review recent commits to repositories
   - Document incident

## Troubleshooting

### Authentication Errors

**Problem:** Workflow fails with "401 Unauthorized" or authentication error

**Solution:**
```bash
# 1. Verify token exists in GitHub secrets
gh secret list --org The1Studio | grep NPM_TOKEN

# 2. Test token locally
export NODE_AUTH_TOKEN="npm_xxxxx..."  # Use token from GitHub secret
npm whoami --registry https://upm.the1studio.org/

# 3. If invalid, generate new token and update secret
npm token create --registry https://upm.the1studio.org/
# Then update GitHub secret
```

### Token Not Found

**Problem:** Workflow can't access `secrets.NPM_TOKEN`

**Solutions:**
1. Verify secret exists at organization level
2. Check repository access settings for the secret
3. Ensure workflow uses `secrets.NPM_TOKEN` (not `secrets.npm_token`)

### Token Expired

**Problem:** Token stopped working after some time

**Note:** Tokens created with `npm token create` don't expire automatically.

**If it expired:**
1. Was it manually set with an expiration?
2. Was it revoked by accident?
3. Check `npm token list` to see token status

**Solution:** Create new token and update GitHub secret

## Advanced: Per-Repository Tokens

If you need different tokens for different repositories:

1. **Create separate tokens:**
   ```bash
   npm token create --registry https://upm.the1studio.org/
   ```

2. **Add as repository secret** (not organization secret):
   - Go to specific repository settings
   - Secrets and variables → Actions
   - Add `NPM_TOKEN` as repository secret

3. **Token precedence:**
   - Repository secret overrides organization secret
   - Useful for testing or isolated repositories

## References

- [npm token documentation](https://docs.npmjs.com/cli/v8/commands/npm-token)
- [GitHub Actions secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Organization secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-an-organization)

## Maintenance Checklist

- [ ] NPM token created and tested
- [ ] Token added to GitHub organization secrets
- [ ] Token access configured for repositories
- [ ] Test workflow completed successfully
- [ ] Token rotation schedule documented
- [ ] Team members notified of new automation
- [ ] Security review completed
