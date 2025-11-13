# UPM Auto Publisher - Webhook Handler

Cloudflare Worker that receives GitHub organization webhook events and automatically triggers UPM package publishing when package.json files are changed.

## Architecture

```
GitHub Organization
├─ TheOneFeature (push event)
├─ UnityBuildScript (push event)
└─ Any registered repo (push event)
        ↓
    Organization Webhook
        ↓
    Cloudflare Worker (this)
        ├─ Verify signature
        ├─ Check if package.json changed
        ├─ Validate repo is registered
        └─ Trigger repository_dispatch
                ↓
    UPMAutoPublisher
        └─ handle-publish-request.yml
```

## Features

- ✅ **Event-driven** - Instant response to push events (<1 second)
- ✅ **Zero setup in repos** - No dispatcher workflow needed
- ✅ **Secure** - HMAC signature verification
- ✅ **Efficient** - Only processes registered repositories
- ✅ **Free** - Cloudflare Workers free tier (100k requests/day)
- ✅ **Reliable** - GitHub webhook retry mechanism

## Prerequisites

1. Cloudflare account (free tier)
2. GitHub PAT with `repo` and `workflow` scopes
3. Webhook secret (generate random string)

## Setup

### 1. Install Wrangler CLI

```bash
npm install -g wrangler

# Login to Cloudflare
wrangler login
```

### 2. Configure Secrets

```bash
cd cloudflare-worker

# Set webhook secret (generate random string)
wrangler secret put GITHUB_WEBHOOK_SECRET
# Enter: (generate with: openssl rand -hex 32)

# Set GitHub PAT
wrangler secret put GITHUB_PAT
# Enter: ghp_your_token_here
```

### 3. Deploy Worker

```bash
npm install
npm run deploy
```

You'll get a URL like: `https://upm-webhook-handler.your-subdomain.workers.dev`

### 4. Create Organization Webhook

```bash
# Save worker URL
WORKER_URL="https://upm-webhook-handler.your-subdomain.workers.dev"

# Generate webhook secret (same as in step 2)
WEBHOOK_SECRET="your-secret-here"

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

# Save the hook ID from response
HOOK_ID=<id-from-response>
```

### 5. Test Webhook

```bash
# Make a test push to any registered repository
cd TheOneFeature
echo "test" >> README.md
git add README.md
git commit -m "test: trigger webhook"
git push

# Check webhook deliveries
gh api /orgs/The1Studio/hooks/$HOOK_ID/deliveries --jq '.[] | {id: .id, status: .status_code, delivered: .delivered_at}'

# View specific delivery
gh api /orgs/The1Studio/hooks/$HOOK_ID/deliveries/{delivery_id}

# Watch worker logs
wrangler tail
```

## How It Works

### 1. GitHub Sends Webhook

When any repository in The1Studio organization receives a push:

```json
{
  "ref": "refs/heads/master",
  "after": "abc123...",
  "repository": {
    "full_name": "The1Studio/TheOneFeature"
  },
  "commits": [
    {
      "added": ["Core/Adapters/package.json"],
      "modified": [],
      "removed": []
    }
  ]
}
```

### 2. Worker Processes Event

```javascript
1. Verify HMAC signature ✓
2. Check event type === 'push' ✓
3. Scan commits for package.json changes ✓
4. Fetch config/repositories.json ✓
5. Validate repository is registered ✓
6. Send repository_dispatch to UPMAutoPublisher ✓
```

### 3. UPMAutoPublisher Publishes

The existing `handle-publish-request.yml` workflow receives the dispatch and publishes packages as normal.

## Monitoring

### View Logs

```bash
# Live tail
wrangler tail

# Filter for errors
wrangler tail --format json | jq 'select(.outcome == "exception")'
```

### Check Webhook Deliveries

```bash
# List recent deliveries
gh api /orgs/The1Studio/hooks/$HOOK_ID/deliveries \
  --jq '.[] | {id: .id, status: .status_code, repo: .request.payload.repository.full_name, delivered: .delivered_at}'

# Redeliver failed webhook
gh api /orgs/The1Studio/hooks/$HOOK_ID/deliveries/{delivery_id}/attempts \
  --method POST
```

### Worker Metrics

View in Cloudflare dashboard:
- Requests per day
- Errors
- CPU time
- Response time

## Troubleshooting

### Webhook Not Triggering

```bash
# Check webhook is active
gh api /orgs/The1Studio/hooks/$HOOK_ID --jq '{active: .active, events: .events, url: .config.url}'

# Check recent deliveries
gh api /orgs/The1Studio/hooks/$HOOK_ID/deliveries

# View delivery details
gh api /orgs/The1Studio/hooks/$HOOK_ID/deliveries/{delivery_id} --jq '{status: .status_code, response: .response}'
```

### Signature Verification Failed

```bash
# Verify secrets match
wrangler secret list

# Regenerate and update
wrangler secret put GITHUB_WEBHOOK_SECRET

# Update webhook secret
gh api /orgs/The1Studio/hooks/$HOOK_ID \
  --method PATCH \
  --field config[secret]="new-secret"
```

### Worker Errors

```bash
# View error logs
wrangler tail --format json | jq 'select(.outcome == "exception") | .logs'

# Check secrets are set
wrangler secret list
```

## Cost

Cloudflare Workers Free Tier:
- ✅ 100,000 requests/day
- ✅ 10ms CPU time per request
- ✅ First 10 worker scripts free

**Expected usage for The1Studio:**
- ~100 pushes/day across all repos
- ~0.5ms CPU time per request
- **$0/month** (well within free tier)

## Updating Worker

```bash
# Make changes to src/index.js
vim src/index.js

# Deploy updates
npm run deploy

# Verify
curl -X POST https://your-worker.workers.dev
```

## Security

1. **Signature Verification**: HMAC-SHA256 validates all webhooks
2. **HTTPS Only**: Rejects insecure SSL
3. **PAT Scope**: Only `repo` and `workflow` permissions
4. **Rate Limiting**: Cloudflare automatic DDoS protection
5. **Secrets**: Encrypted at rest, never logged

## Rollback

```bash
# List deployments
wrangler deployments list

# Rollback to previous
wrangler rollback [deployment-id]
```

## Alternative: No Dispatcher Needed!

With this webhook handler:

**Before:**
```yaml
# Every repo needed this file:
.github/workflows/upm-publish-dispatcher.yml
```

**After:**
```
# Just register in config/repositories.json
# Webhook handles everything automatically!
```

## Support

- Cloudflare Workers: https://developers.cloudflare.com/workers/
- GitHub Webhooks: https://docs.github.com/en/webhooks
- Wrangler CLI: https://developers.cloudflare.com/workers/wrangler/

## License

MIT
