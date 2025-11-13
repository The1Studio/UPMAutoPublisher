# Organization Webhook Setup Guide

**Goal:** Event-driven UPM publishing without dispatcher workflows in each repository.

**Solution:** Cloudflare Worker that receives GitHub organization webhooks and triggers publishing.

---

## 🎯 Benefits

- ✅ **Instant** - Event-driven (<1 second latency)
- ✅ **Zero repo setup** - No dispatcher workflow needed
- ✅ **Free** - Cloudflare Workers free tier
- ✅ **Reliable** - GitHub webhook retry mechanism
- ✅ **Secure** - HMAC signature verification
- ✅ **Scales** - Handles unlimited repositories

---

## 📋 Quick Start

### 1. Deploy Cloudflare Worker (5 minutes)

```bash
cd cloudflare-worker

# Install dependencies
npm install

# Login to Cloudflare
npx wrangler login

# Set secrets
npx wrangler secret put GITHUB_WEBHOOK_SECRET
# Enter: (generate with: openssl rand -hex 32)

npx wrangler secret put GITHUB_PAT
# Enter: your GitHub PAT with repo + workflow scopes

# Deploy
npm run deploy
```

**Result:** You'll get a URL like `https://upm-webhook-handler.your-name.workers.dev`

### 2. Create Organization Webhook (2 minutes)

```bash
# Set variables
WORKER_URL="https://upm-webhook-handler.your-name.workers.dev"
WEBHOOK_SECRET="your-secret-from-step-1"

# Create webhook
gh api /orgs/The1Studio/hooks \
  --method POST \
  --field name=web \
  --field active=true \
  --field config[url]="$WORKER_URL" \
  --field config[content_type]=json \
  --field config[secret]="$WEBHOOK_SECRET" \
  --field config[insecure_ssl]=0 \
  --field events[]=push

# Save the hook_id from response for later
```

### 3. Test (1 minute)

```bash
# Push a change to any registered repository
cd TheOneFeature
git commit --allow-empty -m "test: trigger webhook"
git push

# Check worker logs
cd ../UPMAutoPublisher/cloudflare-worker
npm run tail

# Verify publish was triggered
gh run list --repo The1Studio/UPMAutoPublisher --workflow handle-publish-request.yml --limit 1
```

---

## 🔧 Detailed Setup

### Prerequisites

1. **Cloudflare Account** (free tier sufficient)
   - Sign up: https://dash.cloudflare.com/sign-up

2. **GitHub PAT** with scopes:
   - `repo` - Access repositories
   - `workflow` - Trigger workflows
   - Create: https://github.com/settings/tokens/new

3. **Webhook Secret** (random string)
   - Generate: `openssl rand -hex 32`

### Step 1: Install Wrangler CLI

```bash
# Global installation
npm install -g wrangler

# Or use npx (no installation needed)
npx wrangler --version
```

### Step 2: Login to Cloudflare

```bash
wrangler login
```

This opens a browser for authentication.

### Step 3: Configure Secrets

```bash
cd cloudflare-worker

# Generate webhook secret
WEBHOOK_SECRET=$(openssl rand -hex 32)
echo "Webhook Secret: $WEBHOOK_SECRET"
echo "Save this secret for step 5!"

# Set in Cloudflare
wrangler secret put GITHUB_WEBHOOK_SECRET
# Paste the secret when prompted

# Set GitHub PAT
wrangler secret put GITHUB_PAT
# Paste your GitHub token when prompted

# Verify secrets are set
wrangler secret list
```

### Step 4: Deploy Worker

```bash
npm install
npm run deploy
```

**Output:**
```
✨  Built successfully
🌎  Published upm-webhook-handler
   https://upm-webhook-handler.your-name.workers.dev
```

**Save this URL!** You'll need it for the webhook configuration.

### Step 5: Create Organization Webhook

#### Option A: Using GitHub CLI

```bash
WORKER_URL="https://upm-webhook-handler.your-name.workers.dev"
WEBHOOK_SECRET="your-secret-from-step-3"

gh api /orgs/The1Studio/hooks \
  --method POST \
  --field name=web \
  --field active=true \
  --field config[url]="$WORKER_URL" \
  --field config[content_type]=json \
  --field config[secret]="$WEBHOOK_SECRET" \
  --field config[insecure_ssl]=0 \
  --field events[]=push \
  --jq '{id: .id, url: .config.url, events: .events}'
```

#### Option B: Using GitHub Web UI

1. Go to: https://github.com/organizations/The1Studio/settings/hooks
2. Click "Add webhook"
3. Fill in:
   - **Payload URL**: `https://upm-webhook-handler.your-name.workers.dev`
   - **Content type**: `application/json`
   - **Secret**: Your webhook secret from step 3
   - **SSL verification**: Enable
   - **Which events**: Select "Just the push event"
   - **Active**: ✓ Checked
4. Click "Add webhook"

### Step 6: Test Webhook

```bash
# Method 1: Empty commit (safest)
cd TheOneFeature
git commit --allow-empty -m "test: trigger webhook"
git push

# Method 2: Bump a package version
cd Core/Adapters
npm version patch
git add package.json
git commit -m "test: bump version"
git push

# Watch worker logs
cd ../../UPMAutoPublisher/cloudflare-worker
npm run tail
```

**Expected output in logs:**
```
📦 Push event received: The1Studio/TheOneFeature
📝 Commit: abc1234
👤 Pusher: tuhathe1studio
✅ Package.json changes detected
✅ Repository The1Studio/TheOneFeature is registered and active
✅ Publish workflow triggered successfully
```

### Step 7: Verify Publishing

```bash
# Check handle-publish-request workflow was triggered
gh run list --repo The1Studio/UPMAutoPublisher --workflow handle-publish-request.yml --limit 1

# Check published packages
npm view @the1.packages/core.adapters --registry https://upm.the1studio.org/
```

---

## 🔍 Monitoring

### View Worker Logs

```bash
cd cloudflare-worker

# Live tail
npm run tail

# Format as JSON
npm run tail -- --format json | jq .
```

### Check Webhook Deliveries

```bash
# Get hook ID
HOOK_ID=$(gh api /orgs/The1Studio/hooks --jq '.[] | select(.config.url | contains("upm-webhook")) | .id')

# List recent deliveries
gh api /orgs/The1Studio/hooks/$HOOK_ID/deliveries \
  --jq '.[] | {
    id: .id,
    status: .status_code,
    repo: .request.payload.repository.full_name,
    delivered: .delivered_at
  }'

# View specific delivery
gh api /orgs/The1Studio/hooks/$HOOK_ID/deliveries/{delivery_id} \
  --jq '{
    status: .status_code,
    request: .request.headers,
    response: .response
  }'
```

### Cloudflare Dashboard

View detailed metrics:
1. Go to: https://dash.cloudflare.com/
2. Select your account
3. Click "Workers & Pages"
4. Click "upm-webhook-handler"
5. View metrics:
   - Requests per minute/hour/day
   - Error rate
   - CPU time
   - Response time percentiles

---

## 🐛 Troubleshooting

### Webhook Not Firing

**Check webhook is active:**
```bash
HOOK_ID=$(gh api /orgs/The1Studio/hooks --jq '.[] | select(.config.url | contains("upm-webhook")) | .id')

gh api /orgs/The1Studio/hooks/$HOOK_ID --jq '{
  id: .id,
  active: .active,
  events: .events,
  url: .config.url
}'
```

**Check recent deliveries:**
```bash
gh api /orgs/The1Studio/hooks/$HOOK_ID/deliveries --jq '.[] | {id: .id, status: .status_code}'
```

### Signature Verification Failed

**Symptoms:** Worker returns 401 Unauthorized

**Fix:**
```bash
# Regenerate webhook secret
NEW_SECRET=$(openssl rand -hex 32)

# Update worker secret
wrangler secret put GITHUB_WEBHOOK_SECRET
# Enter: $NEW_SECRET

# Update webhook secret
gh api /orgs/The1Studio/hooks/$HOOK_ID \
  --method PATCH \
  --field config[secret]="$NEW_SECRET"
```

### Worker Returns 500 Error

**View error logs:**
```bash
npm run tail -- --format json | jq 'select(.outcome == "exception")'
```

**Common issues:**
1. **GITHUB_PAT missing**: `wrangler secret list` should show both secrets
2. **PAT expired**: Create new token and update secret
3. **PAT insufficient permissions**: Needs `repo` + `workflow` scopes

### Repository Not Triggering

**Verify repository is registered:**
```bash
jq '.[] | select(.url | contains("TheOneFeature"))' config/repositories.json
```

**Check status is "active":**
```bash
jq '.[] | select(.url | contains("TheOneFeature")) | .status' config/repositories.json
```

### Redeliver Failed Webhook

```bash
# Find failed delivery
gh api /orgs/The1Studio/hooks/$HOOK_ID/deliveries \
  --jq '.[] | select(.status_code != 200) | .id'

# Redeliver
gh api /orgs/The1Studio/hooks/$HOOK_ID/deliveries/{delivery_id}/attempts \
  --method POST
```

---

## 💰 Cost Analysis

### Cloudflare Workers Free Tier

- **Requests**: 100,000/day
- **CPU Time**: 10ms per request
- **Workers**: 10 scripts
- **Storage**: 1 GB

### Expected Usage for The1Studio

Assuming:
- 20 active repositories
- 10 pushes/repo/day = 200 pushes/day
- 1ms CPU time per webhook

**Monthly cost: $0** (well within free tier)

### Upgrade Thresholds

Paid plan needed if:
- > 100,000 requests/day (> 500 repos with 10 pushes/day)
- > 10ms CPU time per request (complex processing)
- > 10 worker scripts

**For The1Studio: Free tier sufficient for years**

---

## 🔄 Updating the Worker

### Deploy Code Changes

```bash
cd cloudflare-worker

# Edit worker code
vim src/index.js

# Deploy update
npm run deploy

# Verify deployment
curl -X POST https://upm-webhook-handler.your-name.workers.dev
```

### Update Secrets

```bash
# Rotate GitHub PAT
wrangler secret put GITHUB_PAT

# Rotate webhook secret
NEW_SECRET=$(openssl rand -hex 32)
wrangler secret put GITHUB_WEBHOOK_SECRET
# Then update GitHub webhook to match
```

### Rollback to Previous Version

```bash
# List deployments
wrangler deployments list

# Rollback
wrangler rollback [deployment-id]
```

---

## 🔐 Security Best Practices

1. **Webhook Secret**
   - Use cryptographically random secret (32+ bytes)
   - Rotate annually
   - Never commit to git

2. **GitHub PAT**
   - Use fine-grained PAT (not classic)
   - Limit to The1Studio organization only
   - Set expiration (90 days recommended)
   - Rotate before expiration

3. **Worker Security**
   - HTTPS only (enforced by Cloudflare)
   - Signature verification on every request
   - No sensitive data in logs
   - Rate limiting by Cloudflare

4. **Monitoring**
   - Enable Cloudflare alerts for errors
   - Monitor webhook delivery failures
   - Set up Discord/Slack notifications for issues

---

## 📚 Next Steps

After setup:

1. ✅ **Remove dispatcher workflows** from existing repos (optional)
2. ✅ **Update documentation** to reflect webhook approach
3. ✅ **Monitor for 1 week** to ensure reliability
4. ✅ **Add new repos** by just updating config/repositories.json

**No more dispatcher workflows needed!** 🎉

---

## 🆚 Comparison: Webhook vs Dispatcher

| Aspect | Dispatcher Workflow | Organization Webhook |
|--------|-------------------|---------------------|
| **Setup per repo** | ✍️ Add workflow file | ✅ None (just register) |
| **Latency** | 5-30 seconds | <1 second |
| **Reliability** | ⚠️ repository_dispatch can fail | ✅ GitHub retry mechanism |
| **Visibility** | ❌ Silent failures possible | ✅ Webhook delivery tracking |
| **Maintenance** | ⚠️ Update each repo | ✅ Update worker once |
| **Cost** | Free (GitHub Actions) | Free (Cloudflare Workers) |
| **Scalability** | 😐 OK | ✅ Excellent (1000+ repos) |

**Recommendation: Organization Webhook for production**

---

## 📞 Support

- Cloudflare Workers: https://developers.cloudflare.com/workers/
- GitHub Webhooks: https://docs.github.com/en/webhooks
- Wrangler CLI: https://developers.cloudflare.com/workers/wrangler/
- Issues: https://github.com/The1Studio/UPMAutoPublisher/issues
