/**
 * UPM Auto Publisher - Cloudflare Worker Webhook Handler
 *
 * Receives GitHub organization webhook push events and automatically
 * triggers package publishing when package.json files are changed
 * in registered repositories.
 */

export default {
  async fetch(request, env) {
    // Only accept POST requests
    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    try {
      // Verify webhook signature
      const signature = request.headers.get('X-Hub-Signature-256');
      const payload = await request.text();

      if (!await verifySignature(payload, signature, env.GITHUB_WEBHOOK_SECRET)) {
        console.error('Invalid webhook signature');
        return new Response('Unauthorized', { status: 401 });
      }

      const event = request.headers.get('X-GitHub-Event');
      const data = JSON.parse(payload);

      // Only handle push events
      if (event !== 'push') {
        return new Response(JSON.stringify({ message: 'Event type not handled', event }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        });
      }

      console.log(`📦 Push event received: ${data.repository.full_name}`);
      console.log(`📝 Commit: ${data.after.substring(0, 7)}`);
      console.log(`👤 Pusher: ${data.pusher.name}`);

      // Check if any commit changed package.json
      const commits = data.commits || [];
      const hasPackageChanges = commits.some(commit => {
        const allFiles = [
          ...(commit.added || []),
          ...(commit.modified || []),
          ...(commit.removed || [])
        ];
        return allFiles.some(file => file.endsWith('package.json'));
      });

      if (!hasPackageChanges) {
        console.log('⏭️  No package.json changes detected');
        return new Response(JSON.stringify({ message: 'No package.json changes' }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        });
      }

      console.log('✅ Package.json changes detected');

      // Fetch registered repositories
      const registeredRepos = await fetchRegisteredRepos(env.GITHUB_PAT);

      // Check if repository is registered
      const repo = data.repository.full_name;
      const isRegistered = registeredRepos.some(r => {
        const repoUrl = r.url.replace('https://github.com/', '');
        return repoUrl === repo && r.status === 'active';
      });

      if (!isRegistered) {
        console.log(`⏭️  Repository ${repo} is not registered or not active`);
        return new Response(JSON.stringify({ message: 'Repository not registered', repo }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        });
      }

      console.log(`✅ Repository ${repo} is registered and active`);

      // Trigger UPMAutoPublisher workflow
      const result = await triggerPublishWorkflow(data, env.GITHUB_PAT);

      console.log('✅ Publish workflow triggered successfully');

      return new Response(JSON.stringify({
        message: 'Publish triggered',
        repository: repo,
        commit: data.after.substring(0, 7),
        result
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      });

    } catch (error) {
      console.error('Error processing webhook:', error);
      return new Response(JSON.stringify({
        error: error.message,
        stack: error.stack
      }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      });
    }
  }
};

/**
 * Verify GitHub webhook signature using HMAC-SHA256
 */
async function verifySignature(payload, signature, secret) {
  if (!signature || !secret) {
    return false;
  }

  // Remove 'sha256=' prefix
  const sig = signature.replace('sha256=', '');

  // Encode secret as Uint8Array
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );

  // Sign payload
  const sigBuffer = await crypto.subtle.sign(
    'HMAC',
    key,
    encoder.encode(payload)
  );

  // Convert to hex
  const computedSig = Array.from(new Uint8Array(sigBuffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');

  // Compare signatures (constant-time comparison)
  return computedSig === sig;
}

/**
 * Fetch registered repositories from UPMAutoPublisher config
 */
async function fetchRegisteredRepos(githubPat) {
  const url = 'https://raw.githubusercontent.com/The1Studio/UPMAutoPublisher/master/config/repositories.json';

  try {
    const response = await fetch(url, {
      headers: {
        'Authorization': `Bearer ${githubPat}`,
        'Accept': 'application/vnd.github.raw+json',
        'User-Agent': 'UPMAutoPublisher-Webhook/1.0'
      }
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch repositories config: ${response.status}`);
    }

    const data = await response.json();
    return data.repositories || [];
  } catch (error) {
    console.error('Error fetching registered repos:', error);
    return [];
  }
}

/**
 * Trigger UPMAutoPublisher workflow via repository_dispatch
 */
async function triggerPublishWorkflow(webhookData, githubPat) {
  const clientPayload = {
    repository: webhookData.repository.full_name,
    commit_sha: webhookData.after,
    commit_message: webhookData.head_commit?.message || 'No message',
    commit_author: webhookData.pusher?.name || webhookData.sender?.login || 'unknown',
    branch: webhookData.ref.replace('refs/heads/', ''),
    package_path: '' // Empty for auto-detection
  };

  const response = await fetch(
    'https://api.github.com/repos/The1Studio/UPMAutoPublisher/dispatches',
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${githubPat}`,
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'UPMAutoPublisher-Webhook/1.0',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        event_type: 'package_publish',
        client_payload: clientPayload
      })
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to trigger workflow: ${response.status} - ${errorText}`);
  }

  return {
    status: response.status,
    dispatched: true
  };
}
