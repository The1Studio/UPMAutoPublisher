# Code Standards & Conventions

**Project**: UPM Auto Publisher
**Version**: 1.2.0
**Security Score**: A (Hardened Production)
**Last Updated**: 2025-11-12

---

## Overview

This document defines coding standards, conventions, and best practices for the UPM Auto Publisher project. These standards ensure consistency, maintainability, security, and reliability across all workflow files, scripts, and configuration.

**Key Principles**:
- **Security First**: All code must follow security best practices (see Security Standards section)
- **Readability Over Cleverness**: Code should be self-documenting and easy to understand
- **Fail Fast**: Validate inputs early, fail with clear error messages
- **Idempotency**: Operations should be safe to re-run
- **Observability**: Log all important operations and decisions

---

## Workflow YAML Standards

### File Naming

```yaml
# ✅ GOOD: Descriptive, kebab-case
handle-publish-request.yml
upm-publish-dispatcher.yml
daily-package-check.yml

# ❌ BAD: Unclear, inconsistent case
publishHandler.yml
UPMDispatch.yml
check.yml
```

**Convention**: Use kebab-case, descriptive names that indicate purpose.

---

### Workflow Structure

```yaml
# Required structure (in order)
name: Descriptive Workflow Name

on:
  # Triggers in logical order

env:
  # Global environment variables with defaults

jobs:
  job-name:
    runs-on: ubuntu-latest  # or [self-hosted, arc, the1studio, org]
    timeout-minutes: 30  # ALWAYS specify timeout

    # IMPORTANT: Explicit permissions (security requirement)
    permissions:
      contents: read  # Minimal permissions needed
      actions: write  # Only if dispatching other workflows

    steps:
      - name: Step description (verb + what)
        # Step implementation
```

**Standards**:
- ✅ Always specify `timeout-minutes` (prevent hung workflows)
- ✅ Always specify `permissions` explicitly (security best practice)
- ✅ Use minimal permissions (principle of least privilege)
- ✅ Step names start with verb (e.g., "Validate", "Build", "Deploy")
- ✅ Job names use kebab-case

---

### Environment Variables

```yaml
# ✅ GOOD: Documented, with defaults
env:
  UPM_REGISTRY: ${{ vars.UPM_REGISTRY || 'https://upm.the1studio.org/' }}
  AUDIT_RETENTION_DAYS: ${{ vars.AUDIT_RETENTION_DAYS || 90 }}

# ❌ BAD: No defaults, unclear purpose
env:
  REGISTRY: ${{ vars.REGISTRY }}
  DAYS: ${{ vars.DAYS }}
```

**Standards**:
- ✅ Always provide fallback defaults
- ✅ Use descriptive variable names (UPM_REGISTRY, not REGISTRY)
- ✅ Document in comments if purpose not obvious
- ✅ Use organization variables for shared config
- ✅ Use secrets for sensitive data (NPM_TOKEN, GH_PAT)

---

### Step Naming Conventions

```yaml
# ✅ GOOD: Clear verb + object structure
- name: Validate dispatch payload
- name: Clone target repository
- name: Setup Node.js
- name: Configure npm authentication
- name: Detect changed packages
- name: Generate changelog with AI

# ❌ BAD: Unclear, no verb, too generic
- name: Payload
- name: Setup
- name: Check
- name: Process
```

**Standards**:
- ✅ Start with action verb
- ✅ Be specific about what is being acted upon
- ✅ Use present tense
- ✅ Keep under 60 characters when possible

---

### Conditional Execution

```yaml
# ✅ GOOD: Clear condition with descriptive check
- name: Send success notification
  if: steps.publish.outputs.success == 'true'

- name: Send failure notification
  if: failure() && steps.publish.outputs.published_count > 0

# ❌ BAD: Complex, hard-to-read conditions
- name: Notify
  if: |
    (steps.publish.outputs.success == 'true' || failure()) &&
    steps.detect.outputs.has_changes == 'true'
```

**Standards**:
- ✅ Use descriptive variable names in conditions
- ✅ Break complex conditions into multiple steps
- ✅ Document non-obvious conditions with comments
- ✅ Use built-in functions: `success()`, `failure()`, `always()`, `cancelled()`

---

### Error Handling

```yaml
# ✅ GOOD: Explicit error handling with context
- name: Publish package
  id: publish
  continue-on-error: false  # Explicit: fail job on error
  run: |
    if ! npm publish --registry "$UPM_REGISTRY"; then
      echo "❌ Publish failed for $package_name"
      echo "Registry: $UPM_REGISTRY"
      echo "Package: $package_name@$new_version"
      exit 1
    fi

# ✅ GOOD: Non-blocking with graceful degradation
- name: Generate changelog
  id: changelog
  continue-on-error: true  # Don't fail workflow if changelog fails
  run: |
    ./scripts/generate-changelog.sh || echo "⚠️  Changelog generation failed, continuing..."

# ❌ BAD: Silent failures
- name: Do something
  run: command || true  # Hides errors
```

**Standards**:
- ✅ Be explicit about `continue-on-error` (default: false)
- ✅ Use `continue-on-error: true` only for non-critical steps
- ✅ Log detailed error context before failing
- ✅ Provide troubleshooting hints in error messages
- ✅ Never silently ignore errors without logging

---

## Bash Scripting Standards

### Shebang & Options

```bash
#!/bin/bash

# ✅ ALWAYS use these options (security + reliability)
set -euo pipefail

# -e: Exit on error
# -u: Exit on undefined variable
# -o pipefail: Exit if any command in pipe fails
```

**Standards**:
- ✅ Always use `#!/bin/bash` (not `#!/bin/sh`)
- ✅ Always use `set -euo pipefail` at script start
- ✅ Use `set -x` for debugging (comment out in production)

---

### Variable Naming

```bash
# ✅ GOOD: Descriptive, clear scope
package_name="com.theone.buildscript"
new_version="1.2.11"
UPM_REGISTRY="https://upm.the1studio.org/"  # Environment/config: UPPER_CASE

# ❌ BAD: Unclear, single letter, no indication of purpose
n="com.theone.buildscript"
v="1.2.11"
reg="https://upm.the1studio.org/"
```

**Standards**:
- ✅ Use lowercase_with_underscores for local variables
- ✅ Use UPPER_CASE for environment variables and constants
- ✅ Use descriptive names (package_name, not pkg or p)
- ✅ Avoid single-letter variables except in short loops

---

### Quoting (CRITICAL for Security)

```bash
# ✅ GOOD: Always quote variables (prevents word splitting, globbing)
echo "Package: $package_name"
cd "$package_dir"
npm publish --registry "$UPM_REGISTRY"

# ✅ GOOD: Use arrays for multiple values
changed_files=()
while IFS= read -r file; do
  changed_files+=("$file")
done < <(git diff --name-only HEAD~1 HEAD)

# ❌ BAD: Unquoted (security vulnerability)
echo Package: $package_name  # Word splitting
cd $package_dir  # Fails with spaces
npm publish --registry $UPM_REGISTRY  # Injection risk
```

**Standards**:
- ✅ ALWAYS quote variables: `"$var"` not `$var`
- ✅ Exception: When testing if variable is set: `[ -n "$var" ]`
- ✅ Use arrays for lists, not space-separated strings
- ✅ Quote command substitutions: `"$(command)"`

---

### Command Injection Prevention (CRITICAL)

```bash
# ✅ GOOD: Use jq for ALL JSON construction (no string interpolation)
jq -n \
  --arg name "$package_name" \
  --arg version "$new_version" \
  --arg repo "$repository" \
  '{
    package: $name,
    version: $version,
    repository: $repo
  }' > payload.json

# ✅ GOOD: Parameterized git commands
git log -1 --pretty='%an' -- "$package_dir"

# ❌ BAD: String interpolation (command injection vulnerability)
echo "{\"package\": \"$package_name\", \"version\": \"$new_version\"}" > payload.json

# ❌ BAD: Unquoted in command (injection vulnerability)
git log -1 --pretty=%an $package_dir
```

**Standards**:
- ✅ ALWAYS use jq with `--arg` for JSON (NEVER string interpolation)
- ✅ ALWAYS quote arguments to commands
- ✅ Use parameterized commands when possible
- ✅ Validate/sanitize all external inputs before use

---

### Input Validation

```bash
# ✅ GOOD: Validate early, fail fast with clear message
validate_semver() {
  local version="$1"
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
    echo "❌ Invalid semver format: $version"
    echo "Expected format: X.Y.Z or X.Y.Z-prerelease"
    return 1
  fi
}

validate_package_name() {
  local name="$1"
  if [[ ! "$name" =~ ^@?[a-z0-9-]+(/[a-z0-9-]+)?$ ]]; then
    echo "❌ Invalid package name: $name"
    echo "Expected format: @scope/name or name"
    return 1
  fi
}

# Use validation
if ! validate_semver "$new_version"; then
  exit 1
fi

# ❌ BAD: No validation (accepts any input)
new_version="$1"  # Could be anything, including malicious input
```

**Standards**:
- ✅ Validate ALL external inputs (user input, file contents, API responses)
- ✅ Use regex patterns for format validation
- ✅ Fail fast with descriptive error messages
- ✅ Document expected formats in error messages

---

### Error Handling & Logging

```bash
# ✅ GOOD: Trap for cleanup (always runs, even on error)
temp_file=$(mktemp)
trap 'rm -f "$temp_file"' EXIT

# ✅ GOOD: Explicit error handling with context
if ! npm publish --registry "$UPM_REGISTRY"; then
  echo "❌ npm publish failed"
  echo "Registry: $UPM_REGISTRY"
  echo "Package: $package_name@$new_version"
  echo "PWD: $PWD"
  echo ""
  echo "Common issues:"
  echo "- Check NPM_TOKEN is valid: npm whoami --registry $UPM_REGISTRY"
  echo "- Check registry is accessible: curl -I $UPM_REGISTRY"
  echo "- Check package.json is valid: jq . package.json"
  exit 1
fi

# ✅ GOOD: Structured logging with emoji (easy to scan)
echo "🔍 Detecting changed packages..."
echo "✅ Package published successfully"
echo "⚠️  Warning: Large package size"
echo "❌ Publish failed"

# ❌ BAD: Silent failure, no context
npm publish --registry "$UPM_REGISTRY" || exit 1
```

**Standards**:
- ✅ Always use trap for cleanup (temp files, lock files)
- ✅ Provide detailed error context before exiting
- ✅ Include troubleshooting hints in error messages
- ✅ Use emoji for visual scanning (🔍 ✅ ⚠️ ❌)
- ✅ Log important decisions and state changes

---

### Retry Logic with Exponential Backoff

```bash
# ✅ GOOD: Standard retry pattern with exponential backoff
npm_view_with_retry() {
  local package_name="$1"
  local version="$2"
  local max_attempts=5
  local attempt=1
  local delay=1

  while [ $attempt -le $max_attempts ]; do
    echo "🔍 Checking if $package_name@$version exists (attempt $attempt/$max_attempts)..."

    if npm view "$package_name@$version" --registry "$UPM_REGISTRY" &>/dev/null; then
      return 0  # Version exists
    fi

    # Check for 404 (version doesn't exist) vs other errors
    local exit_code=$?
    if [ $exit_code -eq 1 ]; then
      return 1  # Version doesn't exist (404)
    fi

    # Rate limit or network error - retry
    if [ $attempt -lt $max_attempts ]; then
      echo "⚠️  Attempt $attempt failed, retrying in ${delay}s..."
      sleep $delay
      delay=$((delay * 2))  # Exponential backoff: 1s, 2s, 4s, 8s, 16s
    fi

    ((attempt++))
  done

  echo "❌ Failed after $max_attempts attempts"
  return 1
}
```

**Standards**:
- ✅ Use exponential backoff: 1s, 2s, 4s, 8s, 16s
- ✅ Limit retry attempts (3-5 typically)
- ✅ Log each attempt with attempt number
- ✅ Distinguish between retryable (429, 5xx) and non-retryable (404, 400) errors
- ✅ Final failure message includes total attempts

---

### Temporary File Security

```bash
# ✅ GOOD: Secure temp file handling
temp_file=$(mktemp)
chmod 600 "$temp_file"  # Explicit permissions (owner read/write only)
trap 'rm -f "$temp_file"' EXIT  # Always cleanup

echo "sensitive data" > "$temp_file"
# Use temp file...
# Cleanup handled by trap

# ❌ BAD: Insecure temp file
temp_file="/tmp/myfile.tmp"  # Predictable name, race condition
echo "sensitive data" > "$temp_file"  # Default permissions (644, world-readable)
# No cleanup
```

**Standards**:
- ✅ Use `mktemp` for temp files (random names, no race conditions)
- ✅ Set explicit permissions: `chmod 600` (owner only)
- ✅ Always use trap for cleanup: `trap 'rm -f "$temp_file"' EXIT`
- ✅ Never use predictable names like `/tmp/myfile.tmp`

---

### Function Definitions

```bash
# ✅ GOOD: Documented, single responsibility, clear parameters
# Validates semver format (X.Y.Z or X.Y.Z-prerelease)
# Arguments:
#   $1: Version string to validate
# Returns:
#   0 if valid, 1 if invalid
validate_semver() {
  local version="$1"

  if [[ -z "$version" ]]; then
    echo "❌ Version is empty"
    return 1
  fi

  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
    echo "❌ Invalid semver format: $version"
    return 1
  fi

  return 0
}

# ❌ BAD: No documentation, unclear purpose, multiple responsibilities
check() {
  local v="$1"
  [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && return 0 || return 1
}
```

**Standards**:
- ✅ Document function purpose, parameters, and return values
- ✅ Use `local` for all function variables
- ✅ Single responsibility (one function does one thing)
- ✅ Return 0 for success, 1+ for errors
- ✅ Descriptive function names (verb + noun)

---

## JSON Configuration Standards

### Structure

```json
{
  "$schema": "./schema.json",
  "repositories": [
    {
      "url": "https://github.com/The1Studio/UnityBuildScript",
      "status": "active"
    }
  ]
}
```

**Standards**:
- ✅ Always include `$schema` reference
- ✅ Use consistent 2-space indentation
- ✅ No trailing commas
- ✅ Required fields first, optional fields last
- ✅ Alphabetical order for object keys (when logical)

---

### Validation

```bash
# ✅ GOOD: Always validate JSON syntax and schema
validate_json() {
  local file="$1"

  # Check JSON syntax
  if ! jq empty "$file" 2>/dev/null; then
    echo "❌ Invalid JSON syntax in $file"
    return 1
  fi

  # Check against schema
  if ! ajv validate -s config/schema.json -d "$file"; then
    echo "❌ JSON does not match schema"
    return 1
  fi

  echo "✅ JSON validation passed"
  return 0
}
```

**Standards**:
- ✅ Validate syntax with `jq empty`
- ✅ Validate schema with `ajv-cli`
- ✅ Never commit without validation
- ✅ Include validation in CI/CD (pre-deployment-check.sh)

---

### Manipulation (Security Critical)

```bash
# ✅ GOOD: Use jq for ALL JSON manipulation
jq --arg url "$repo_url" \
   --arg status "active" \
   '.repositories += [{"url": $url, "status": $status}]' \
   config/repositories.json > config/repositories.json.tmp
mv config/repositories.json.tmp config/repositories.json

# ❌ BAD: String manipulation (fragile, injection risk)
echo "{\"url\": \"$repo_url\", \"status\": \"active\"}" >> config/repositories.json
```

**Standards**:
- ✅ ALWAYS use jq with `--arg` for modifications
- ✅ Write to temp file, then move (atomic operation)
- ✅ Validate after modification
- ✅ Never use string concatenation or sed for JSON

---

## Security Standards (CRITICAL)

### Input Validation Patterns

```bash
# Semver validation
^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$

# Package name validation
^@?[a-z0-9-]+(/[a-z0-9-]+)?$

# URL validation
^https://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/?$

# GitHub repository URL
^https://github\.com/[a-zA-Z0-9_-]+/[a-zA-Z0-9._-]+$
```

**Standards**:
- ✅ Validate ALL external inputs before use
- ✅ Use strict regex patterns (anchored with ^ and $)
- ✅ Fail early with descriptive errors
- ✅ Log validation failures for security monitoring

---

### Markdown Injection Prevention

```bash
# ✅ GOOD: Validate markdown links, HTML, code blocks
validate_markdown_link() {
  local link="$1"

  # Check for script injection
  if [[ "$link" =~ javascript:|data:|vbscript: ]]; then
    echo "❌ Potentially malicious link: $link"
    return 1
  fi

  # Check for valid protocols
  if [[ ! "$link" =~ ^https?:// ]]; then
    echo "❌ Invalid link protocol: $link"
    return 1
  fi

  return 0
}

# Validate before using in Discord notification
if ! validate_markdown_link "$commit_url"; then
  commit_url="<invalid URL removed>"
fi
```

**Standards**:
- ✅ Validate all URLs in notifications (Discord, Slack, etc.)
- ✅ Block javascript:, data:, vbscript: protocols
- ✅ Only allow http: and https: protocols
- ✅ Sanitize HTML tags in user-provided content
- ✅ Validate code block syntax to prevent injection

---

### Secret Management

```bash
# ✅ GOOD: Never log secrets
if [ -z "$NPM_TOKEN" ]; then
  echo "❌ NPM_TOKEN is not set"
  exit 1
fi
# Use NPM_TOKEN without logging it

# ✅ GOOD: Validate token without exposing
if ! gh auth status 2>&1 | grep -q "Logged in"; then
  echo "❌ GH_PAT is invalid or expired"
  exit 1
fi

# ❌ BAD: Logs secret
echo "Using token: $NPM_TOKEN"

# ❌ BAD: Exposes token in process list
ps aux | grep "$NPM_TOKEN"
```

**Standards**:
- ✅ NEVER log secrets (tokens, passwords, API keys)
- ✅ NEVER include secrets in error messages
- ✅ Validate secrets without exposing them
- ✅ Use GitHub secrets, not environment files
- ✅ Rotate tokens regularly (90 days for GH_PAT)

---

### Rate Limiting

```bash
# ✅ GOOD: Handle rate limits gracefully
npm_publish_with_rate_limit() {
  local max_attempts=3
  local attempt=1
  local delay=5

  while [ $attempt -le $max_attempts ]; do
    echo "📤 Publishing (attempt $attempt/$max_attempts)..."

    if npm publish --registry "$UPM_REGISTRY"; then
      return 0
    fi

    # Check if rate limited (429)
    local exit_code=$?
    if [ $exit_code -eq 429 ] || [ $exit_code -eq 1 ]; then
      if [ $attempt -lt $max_attempts ]; then
        echo "⚠️  Rate limited, waiting ${delay}s before retry..."
        sleep $delay
        delay=$((delay * 2))
      fi
    else
      # Other error, don't retry
      return $exit_code
    fi

    ((attempt++))
  done

  return 1
}
```

**Standards**:
- ✅ Detect rate limit responses (429 status)
- ✅ Exponential backoff before retry
- ✅ Limit retry attempts to prevent infinite loops
- ✅ Log rate limit occurrences for monitoring

---

## Concurrency Control Standards

### GitHub Actions Concurrency

```yaml
# ✅ GOOD: Prevent race conditions with concurrency groups
concurrency:
  group: publish-${{ github.event.client_payload.repository }}
  cancel-in-progress: false  # Don't cancel running publishes

# ✅ GOOD: Cancel old runs for non-critical workflows
concurrency:
  group: sync-status-${{ github.ref }}
  cancel-in-progress: true  # Cancel old sync runs
```

**Standards**:
- ✅ Use `concurrency.group` to prevent race conditions
- ✅ Include unique identifier in group (repository, commit, etc.)
- ✅ Set `cancel-in-progress: false` for critical operations (publish)
- ✅ Set `cancel-in-progress: true` for monitoring/reporting workflows

---

## Docker Standards

### Image Versioning

```yaml
# ✅ GOOD: Pin to specific version
image: myoung34/github-runner:2.311.0

# ❌ BAD: Uses latest (unpredictable updates)
image: myoung34/github-runner:latest
```

**Standards**:
- ✅ ALWAYS pin to specific versions (no `latest`)
- ✅ Document update procedure in comments
- ✅ Test new versions before updating production
- ✅ Use Dependabot for automated version updates

---

### Resource Limits

```yaml
# ✅ GOOD: Explicit resource limits
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 4G
    reservations:
      cpus: '1.0'
      memory: 2G
```

**Standards**:
- ✅ Always specify resource limits
- ✅ Set both limits and reservations
- ✅ Base on actual usage patterns
- ✅ Monitor and adjust as needed

---

### Secret Management

```yaml
# ✅ GOOD: Use Docker secrets
services:
  runner:
    secrets:
      - github_pat
    environment:
      - ACCESS_TOKEN_FILE=/run/secrets/github_pat

secrets:
  github_pat:
    file: ./.secrets/github_pat

# ❌ BAD: Environment variables (visible in docker inspect)
services:
  runner:
    environment:
      - GITHUB_PAT=${GITHUB_PAT}
```

**Standards**:
- ✅ Use Docker secrets for sensitive data
- ✅ Mount secrets as files, not environment variables
- ✅ Set file permissions to 600 (owner only)
- ✅ Never commit secret files to git

---

## Testing & Validation Standards

### Pre-Deployment Validation

```bash
# Run before any production deployment
./scripts/pre-deployment-check.sh

# Validates:
# - File structure (12 critical files)
# - JSON syntax (repositories.json, package-cache.json)
# - Bash syntax (9 scripts with shellcheck)
# - Security best practices (28 fixes)
# - Dependencies (node, npm, jq, gh, curl, git)
# - Workflow YAML syntax
# - Docker configuration
```

**Standards**:
- ✅ Run pre-deployment-check.sh before every production deploy
- ✅ Fix all CRITICAL and ERROR findings before deployment
- ✅ Address WARNING findings when possible
- ✅ Never skip validation to "save time"

---

### Shellcheck Integration

```bash
# ✅ GOOD: Run shellcheck on all bash scripts
shellcheck -x scripts/*.sh

# Address findings:
# SC2086: Quote variables
# SC2154: Variable used but not defined
# SC2181: Check exit code directly (if command; then)
# SC2124: Concatenation with arrays
```

**Standards**:
- ✅ Run shellcheck on all bash scripts
- ✅ Fix all errors and warnings
- ✅ Use shellcheck directives sparingly: `# shellcheck disable=SC2086`
- ✅ Document why directive is needed

---

## Documentation Standards

### Inline Comments

```yaml
# ✅ GOOD: Comments explain WHY, not WHAT
# Use exponential backoff to handle transient registry failures
delay=$((delay * 2))

# Validate payload to prevent command injection attacks
if ! validate_payload "$payload"; then
  exit 1
fi

# ❌ BAD: Comments repeat the code
# Double the delay
delay=$((delay * 2))

# Check if payload is valid
if ! validate_payload "$payload"; then
  exit 1
fi
```

**Standards**:
- ✅ Explain WHY, not WHAT (code shows what)
- ✅ Document non-obvious decisions
- ✅ Link to relevant ADRs or issues
- ✅ Update comments when code changes

---

### Error Messages

```bash
# ✅ GOOD: Actionable error messages
echo "❌ npm publish failed"
echo "Package: $package_name@$new_version"
echo "Registry: $UPM_REGISTRY"
echo ""
echo "Troubleshooting:"
echo "1. Check NPM_TOKEN: npm whoami --registry $UPM_REGISTRY"
echo "2. Check registry health: curl -I $UPM_REGISTRY"
echo "3. Check package.json: jq . package.json"
echo "4. See docs/troubleshooting.md for more help"

# ❌ BAD: Generic, not actionable
echo "Error occurred"
```

**Standards**:
- ✅ Include context (what failed, why, with what values)
- ✅ Provide troubleshooting steps
- ✅ Link to documentation
- ✅ Use emoji for visual distinction (❌ ⚠️ ✅)

---

## Performance Standards

### Timeout Specifications

```yaml
# ✅ GOOD: Appropriate timeouts based on operation
jobs:
  publish:
    timeout-minutes: 30  # Publishing can take 15-20 min

  dispatcher:
    timeout-minutes: 5  # Should complete in 1-2 min

steps:
  - name: Health check
    timeout-minutes: 2  # Quick operation

  - name: Clone repository
    timeout-minutes: 10  # Can be slow for large repos
```

**Standards**:
- ✅ Always specify timeouts (job and step level)
- ✅ Set realistic timeouts (2x expected duration)
- ✅ Use shorter timeouts for quick operations (health checks, API calls)
- ✅ Use longer timeouts for slow operations (cloning, publishing)

---

### Optimization Patterns

```bash
# ✅ GOOD: Shallow clone (faster)
git clone --depth 1 --branch master "$repo_url"

# ✅ GOOD: Parallel processing when independent
npm view package1 & npm view package2 & wait

# ✅ GOOD: Cache expensive computations
if [ ! -f package-cache.json ]; then
  build_package_cache
fi

# ❌ BAD: Full clone (slow)
git clone "$repo_url"

# ❌ BAD: Sequential when could be parallel
npm view package1
npm view package2
```

**Standards**:
- ✅ Use shallow clones when full history not needed
- ✅ Parallelize independent operations
- ✅ Cache expensive computations
- ✅ Use `--depth 1` for git clones

---

## Version Control Standards

### Commit Messages

```bash
# ✅ GOOD: Conventional Commits format
feat: add AI-powered changelog generation
fix: prevent command injection in JSON construction
docs: update troubleshooting guide with rate limit info
chore: update dependencies to latest versions
security: fix markdown injection vulnerability

# ❌ BAD: Unclear, no context
update code
fix bug
changes
```

**Standards**:
- ✅ Use Conventional Commits format (type: description)
- ✅ Types: feat, fix, docs, chore, test, refactor, security
- ✅ Keep first line under 72 characters
- ✅ Use imperative mood ("add" not "added")
- ✅ Reference issues when relevant (#123)

---

### Branch Naming

```bash
# ✅ GOOD: Descriptive, categorized
feature/ai-changelog-generation
fix/command-injection-vulnerability
docs/update-security-guide
chore/update-dependencies

# ❌ BAD: Unclear, no category
new-feature
updates
fix123
```

**Standards**:
- ✅ Use category prefix: feature/, fix/, docs/, chore/
- ✅ Use kebab-case for branch name
- ✅ Be descriptive (what is being added/fixed)
- ✅ Keep under 50 characters when possible

---

## Summary

These standards ensure:
- **Security**: 28 security issues fixed, A rating maintained
- **Reliability**: >99% success rate through proper error handling
- **Maintainability**: Clear, documented, consistent code
- **Observability**: Comprehensive logging and error messages
- **Performance**: Optimized operations with appropriate timeouts

**Key Takeaways**:
- ✅ Security first: validate all inputs, quote all variables, use jq for JSON
- ✅ Fail fast: detect errors early, provide actionable messages
- ✅ Be explicit: timeouts, permissions, error handling
- ✅ Document why: comments explain decisions, not repetition
- ✅ Test everything: pre-deployment validation is mandatory

---

**Document Owner**: The1Studio DevOps Team
**Review Cycle**: Quarterly
**Next Review**: 2026-02-12
**Last Updated**: 2025-11-12
