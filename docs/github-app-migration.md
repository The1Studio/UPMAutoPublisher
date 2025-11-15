# GitHub App Migration - UPM Auto Publisher

**Date:** 2025-11-15
**Status:** ✅ Complete and Production Ready

## Overview

Migrated Cloudflare Worker authentication from Personal Access Token (PAT) to GitHub App for improved security and automatic token management.

## Why GitHub App?

**Problems with PAT:**
- 401 authentication errors
- Manual token rotation required
- Organization-wide permissions
- No automatic renewal

**Benefits of GitHub App:**
- Automatic installation token generation (1-hour tokens)
- Fine-grained repository permissions
- No manual token rotation
- Better security and auditability

## Architecture

### Authentication Flow

```
1. Worker receives webhook from GitHub
   ↓
2. Worker generates JWT using App ID + Private Key
   ↓
3. Worker uses JWT to fetch installation ID for The1Studio org
   ↓
4. Worker requests installation access token (1-hour lifetime)
   ↓
5. Worker uses installation token to call repository_dispatch API
   ↓
6. GitHub triggers workflow in UPMAutoPublisher repo
```

### Key Components

1. **JWT Generation** (`generateJWT()` function)
   - RS256 signing algorithm
   - Uses Web Crypto API (no external libraries)
   - PKCS#8 format private key required
   - App ID must be integer type in JWT payload

2. **Installation Token** (`getInstallationToken()` function)
   - Fetches installation ID for The1Studio organization
   - Creates short-lived (1-hour) access token
   - Token automatically regenerated on each webhook

3. **Worker Secrets**
   - `GITHUB_APP_ID`: `2294359`
   - `GITHUB_APP_PRIVATE_KEY`: PKCS#8 format private key
   - `GITHUB_WEBHOOK_SECRET`: Webhook signature verification

## GitHub App Setup

### App Details
- **Name:** UPM Auto Publisher
- **App ID:** 2294359
- **Organization:** The1Studio
- **Installation ID:** 94789235

### Permissions
- **Contents:** Read and write (required for `repository_dispatch`)
- **Metadata:** Read-only
- **Actions:** Write (optional, for workflow triggers)

### Events
- **push** - Receives webhook when code is pushed

### Repository Access
✅ **CRITICAL:** The App must have access to BOTH repositories:
- `The1Studio/TheOne.ProjectSetup` (source of webhooks)
- `The1Studio/UPMAutoPublisher` (target for `repository_dispatch`)

Without access to UPMAutoPublisher, the API returns `403 - Resource not accessible by integration`.

## Setup Process (For Future Reference)

### 1. Create GitHub App via Manifest

Used automated manifest flow to create app:

```json
{
  "name": "UPM Auto Publisher",
  "url": "https://github.com/The1Studio/UPMAutoPublisher",
  "hook_attributes": {
    "url": "https://upm-webhook-handler.tuha.workers.dev"
  },
  "redirect_url": "https://github.com/The1Studio/UPMAutoPublisher",
  "description": "Automatically publishes UPM packages when package.json is updated",
  "public": false,
  "default_permissions": {
    "contents": "write",
    "metadata": "read",
    "actions": "write"
  },
  "default_events": ["push"]
}
```

POST form to: `https://github.com/organizations/The1Studio/settings/apps/new`

### 2. Exchange Code for Credentials

After app creation, GitHub redirects with temporary code. Exchange code for permanent credentials:

```bash
curl -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/app-manifests/${CODE}/conversions"
```

Returns:
- App ID
- Webhook secret
- Private key (PKCS#1 format)

### 3. Convert Private Key Format

GitHub provides PKCS#1 format, but Web Crypto API requires PKCS#8:

```bash
openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt \
  -in private-key.pem \
  -out private-key-pkcs8.pem
```

### 4. Configure Worker Secrets

```bash
# Set App ID
echo "2294359" | npx wrangler secret put GITHUB_APP_ID

# Set private key (PKCS#8 format)
cat private-key-pkcs8.pem | npx wrangler secret put GITHUB_APP_PRIVATE_KEY

# Set webhook secret
echo "webhook-secret-here" | npx wrangler secret put GITHUB_WEBHOOK_SECRET
```

### 5. Install App on Organization

1. Go to: `https://github.com/apps/upm-auto-publisher/installations/new`
2. Select The1Studio organization
3. Choose repository access:
   - **All repositories** OR
   - **Select repositories:** TheOne.ProjectSetup, UPMAutoPublisher
4. Click Install

### 6. Accept Permission Changes

When updating permissions via GitHub UI:
1. Go to App settings → Permissions & events
2. Update permissions
3. Click "Save changes"
4. Organization owner receives notification
5. Accept permission request
6. Tokens automatically regenerate with new permissions

## Critical Implementation Details

### JWT Payload - App ID Must Be Integer

```javascript
// ❌ WRONG - This causes "Issuer claim must be Integer" error
const payload = {
  iss: appId  // appId is string from env var
};

// ✅ CORRECT - Parse to integer
const parsedAppId = parseInt(appId, 10);
const payload = {
  iss: parsedAppId  // Now integer type
};
```

### Private Key Import - PKCS#8 Required

```javascript
// Import PKCS#8 format
const key = await crypto.subtle.importKey(
  'pkcs8',  // Format must be 'pkcs8', not 'pkcs1'
  binaryDer,
  { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
  false,
  ['sign']
);
```

If using PKCS#1 format, you'll get:
```
Failed to import private key: <error>. GitHub App private keys must be in PKCS#8 format.
Convert using: openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt -in private-key.pem -out private-key-pkcs8.pem
```

### Repository Access - Must Include Target Repo

```
403 - Resource not accessible by integration
```

This error means the GitHub App doesn't have access to the repository you're trying to call `repository_dispatch` on.

**Fix:**
1. Go to: `https://github.com/organizations/The1Studio/settings/installations`
2. Click "Configure" on UPM Auto Publisher
3. Under "Repository access", add UPMAutoPublisher to selected repositories
4. Click "Save"

## Troubleshooting

### JWT Generation Fails

**Symptom:** `401 - 'Issuer' claim ('iss') must be an Integer`

**Fix:** Ensure App ID is parsed as integer: `parseInt(appId, 10)`

---

**Symptom:** `Failed to import private key`

**Fix:** Convert private key to PKCS#8 format using OpenSSL command above

---

### Installation Token Fails

**Symptom:** `GitHub App not installed on The1Studio organization`

**Fix:** Install app on The1Studio org via GitHub UI

---

**Symptom:** `Failed to create installation token: 404`

**Fix:** Installation ID might have changed. Worker automatically fetches current installation ID.

---

### Repository Dispatch Fails

**Symptom:** `403 - Resource not accessible by integration`

**Fix:** Grant app access to target repository (UPMAutoPublisher)

---

**Symptom:** `403 - Resource not accessible` after granting access

**Fix:** Update Contents permission to "Read and write" in app settings

---

## Testing

Successful end-to-end test flow:

1. Bumped version in TheOne.ProjectSetup package.json (v1.3.4)
2. Pushed to master (commit 350d1f9)
3. GitHub sent webhook to Worker
4. Worker logs showed:
   ```
   ✅ Package.json changes detected
   ✅ Repository The1Studio/TheOne.ProjectSetup is registered and active
   📱 Found installation ID: 94789235
   🔑 Installation token created, expires: 2025-11-15T05:22:02Z
   ✅ Publish workflow triggered successfully
   ```
5. GitHub Actions workflow started in UPMAutoPublisher
6. Workflow completed successfully (run #19357514098)

## Files Modified

### `cloudflare-worker/src/index.js`

**Added Functions:**
- `generateJWT(appId, privateKeyPem)` - JWT generation with RS256
- `base64UrlEncode(data)` - JWT-compatible encoding
- `base64Decode(base64)` - Private key decoding
- `getInstallationToken(env)` - Fetch installation access token

**Modified Functions:**
- `fetch()` handler - Now uses `getInstallationToken()` instead of PAT
- `triggerPublishWorkflow()` - Accepts installation token parameter

**Environment Variables Used:**
- `GITHUB_APP_ID` - GitHub App identifier
- `GITHUB_APP_PRIVATE_KEY` - PKCS#8 private key
- `GITHUB_WEBHOOK_SECRET` - Webhook signature verification

## Security Considerations

### Secrets Management

✅ **Private Key:** Stored in Cloudflare Worker secrets (encrypted at rest)
✅ **App ID:** Stored in Worker secrets (not sensitive but consistent)
✅ **Webhook Secret:** Stored in Worker secrets for signature verification

**Important:** Private key never exposed in logs or code. Only used internally for JWT signing.

### Token Lifetime

- **JWT:** 10 minutes (600 seconds)
- **Installation Token:** 1 hour (auto-generated per request)
- **No manual rotation:** GitHub handles token lifecycle

### Permissions

- **Contents: write** - Required for `repository_dispatch` only
- **Metadata: read** - Standard GitHub App permission
- **Actions: write** - Optional, for workflow management

**Least Privilege:** App only has access to required repositories, not entire org.

## Migration Timeline

**2025-11-15 (10:30 AM - 11:30 AM):**
- ✅ Created GitHub App via manifest flow
- ✅ Exchanged code for credentials
- ✅ Converted private key to PKCS#8 format
- ✅ Updated Worker code with JWT generation
- ✅ Configured Worker secrets
- ✅ Installed app on The1Studio organization
- ✅ Fixed JWT integer issue
- ✅ Fixed private key format issue
- ✅ Fixed App ID secret value issue
- ✅ Granted repository access to UPMAutoPublisher
- ✅ Updated Contents permission to "Read and write"
- ✅ Verified end-to-end flow with successful test
- ✅ Removed debug logging
- ✅ Deployed cleaned Worker code

**Total Time:** ~1 hour (including troubleshooting)

## Maintenance

### Private Key Rotation

GitHub Apps don't automatically rotate private keys. To rotate:

1. Generate new private key in GitHub App settings
2. Convert to PKCS#8 format
3. Update `GITHUB_APP_PRIVATE_KEY` secret in Worker
4. Old key continues working during transition
5. Revoke old key after verifying new key works

**Recommended Frequency:** Annually or after security incident

### Monitoring

Watch for these errors in Worker logs:

- `Failed to generate JWT` - Check App ID and private key format
- `Failed to fetch installations` - Check JWT is valid
- `GitHub App not installed` - Verify app installed on org
- `Failed to create installation token` - Check installation exists
- `Failed to trigger workflow: 403` - Check repository access and permissions

### Future Improvements

Optional enhancements:
- Cache installation ID (currently fetched every request)
- Add retry logic for transient GitHub API errors
- Monitor token expiration proactively
- Add metrics for JWT generation latency

## References

- **GitHub Apps Docs:** https://docs.github.com/apps
- **JWT Authentication:** https://docs.github.com/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app
- **repository_dispatch API:** https://docs.github.com/rest/repos/repos#create-a-repository-dispatch-event
- **Web Crypto API:** https://developer.mozilla.org/en-US/docs/Web/API/Web_Crypto_API

---

**Status:** ✅ Production ready and verified working
**Last Updated:** 2025-11-15
**Maintained By:** The1Studio DevOps Team
