/**
 * UPM Auto Publisher - Cloudflare Worker Webhook Handler
 *
 * Receives GitHub organization webhook push events and automatically
 * triggers package publishing when package.json files are changed
 * in registered repositories.
 *
 * Updated: 2025-11-15 - Migrated to GitHub App authentication
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

      // Fetch registered repositories (no auth needed for public repo)
      const registeredRepos = await fetchRegisteredRepos();

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

      // Get GitHub App installation token
      const installationToken = await getInstallationToken(env);

      // Trigger UPMAutoPublisher workflow
      const result = await triggerPublishWorkflow(data, installationToken);

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
async function fetchRegisteredRepos() {
  const url = 'https://raw.githubusercontent.com/The1Studio/UPMAutoPublisher/master/config/repositories.json';

  try {
    // Note: raw.githubusercontent.com doesn't need auth for public repos
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'UPMAutoPublisher-Webhook/2.0',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache'
      },
      cf: {
        cacheTtl: 0,
        cacheEverything: false
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
 * Generate JWT for GitHub App authentication
 */
async function generateJWT(appId, privateKeyPem) {
  const now = Math.floor(Date.now() / 1000);

  // JWT header
  const header = {
    alg: 'RS256',
    typ: 'JWT'
  };

  // JWT payload
  const parsedAppId = parseInt(appId, 10);

  const payload = {
    iat: now - 60, // Issued 60 seconds in the past to allow for clock drift
    exp: now + 600, // Expires 10 minutes from now
    iss: parsedAppId // Must be an integer
  };

  // Encode header and payload
  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const message = `${encodedHeader}.${encodedPayload}`;

  // Import private key
  // GitHub App private keys are in PKCS#1 format
  const pemContents = privateKeyPem
    .replace('-----BEGIN RSA PRIVATE KEY-----', '')
    .replace('-----END RSA PRIVATE KEY-----', '')
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');

  const binaryDer = base64Decode(pemContents);

  // Try to import as PKCS#8 first (newer format), fall back to PKCS#1 if needed
  let key;
  try {
    key = await crypto.subtle.importKey(
      'pkcs8',
      binaryDer,
      {
        name: 'RSASSA-PKCS1-v1_5',
        hash: 'SHA-256'
      },
      false,
      ['sign']
    );
  } catch (e) {
    // If PKCS#8 fails, the key is likely in PKCS#1 format
    // We need to convert it, but Web Crypto API doesn't support PKCS#1 directly
    throw new Error(`Failed to import private key: ${e.message}. GitHub App private keys must be in PKCS#8 format. Convert using: openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt -in private-key.pem -out private-key-pkcs8.pem`);
  }

  // Sign the message
  const encoder = new TextEncoder();
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    encoder.encode(message)
  );

  // Encode signature
  const encodedSignature = base64UrlEncode(signature);

  return `${message}.${encodedSignature}`;
}

/**
 * Base64 URL encode
 */
function base64UrlEncode(data) {
  let base64;

  if (typeof data === 'string') {
    base64 = btoa(data);
  } else if (data instanceof ArrayBuffer) {
    const bytes = new Uint8Array(data);
    let binary = '';
    for (let i = 0; i < bytes.length; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    base64 = btoa(binary);
  } else {
    throw new Error('Unsupported data type for base64UrlEncode');
  }

  return base64
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

/**
 * Base64 decode
 */
function base64Decode(base64) {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

/**
 * Get GitHub App installation token
 */
async function getInstallationToken(env) {
  // Generate JWT
  const jwt = await generateJWT(env.GITHUB_APP_ID, env.GITHUB_APP_PRIVATE_KEY);

  // Get installation ID for The1Studio organization
  const installationsResponse = await fetch(
    'https://api.github.com/app/installations',
    {
      headers: {
        'Authorization': `Bearer ${jwt}`,
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'UPMAutoPublisher-Webhook/2.0'
      }
    }
  );

  if (!installationsResponse.ok) {
    const errorText = await installationsResponse.text();
    throw new Error(`Failed to fetch installations: ${installationsResponse.status} - ${errorText}`);
  }

  const installations = await installationsResponse.json();
  const installation = installations.find(i => i.account.login === 'The1Studio');

  if (!installation) {
    throw new Error('GitHub App not installed on The1Studio organization');
  }

  console.log(`📱 Found installation ID: ${installation.id}`);

  // Get installation token
  const tokenResponse = await fetch(
    `https://api.github.com/app/installations/${installation.id}/access_tokens`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${jwt}`,
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'UPMAutoPublisher-Webhook/2.0'
      }
    }
  );

  if (!tokenResponse.ok) {
    const errorText = await tokenResponse.text();
    throw new Error(`Failed to create installation token: ${tokenResponse.status} - ${errorText}`);
  }

  const tokenData = await tokenResponse.json();
  console.log(`🔑 Installation token created, expires: ${tokenData.expires_at}`);

  return tokenData.token;
}

/**
 * Trigger UPMAutoPublisher workflow via repository_dispatch
 */
async function triggerPublishWorkflow(webhookData, installationToken) {
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
        'Authorization': `Bearer ${installationToken}`,
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'UPMAutoPublisher-Webhook/2.0',
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
