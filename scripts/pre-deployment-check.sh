#!/usr/bin/env bash
# pre-deployment-check.sh
# Comprehensive pre-deployment validation for UPM Auto Publisher
# Run this before deploying to production or setting up self-hosted runners

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Emojis
CHECK="✅"
CROSS="❌"
WARN="⚠️"
INFO="ℹ️"

# Counters
passed=0
failed=0
warnings=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 UPM Auto Publisher - Pre-Deployment Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# =============================================================================
# Section 1: File Structure Validation
# =============================================================================
echo "${BLUE}[1/7] Checking File Structure${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

required_files=(
  ".github/workflows/publish-upm.yml"
  ".github/workflows/register-repos.yml"
  "config/repositories.json"
  "config/schema.json"
  "scripts/audit-repos.sh"
  "scripts/check-single-repo.sh"
  "scripts/quick-check.sh"
  "scripts/validate-config.sh"
  "docs/setup-instructions.md"
  "docs/configuration.md"
  "docs/security-improvements.md"
  "README.md"
)

for file in "${required_files[@]}"; do
  if [ -f "$file" ]; then
    echo "  ${CHECK} $file"
    passed=$((passed + 1))
  else
    echo "  ${CROSS} Missing: $file"
    failed=$((failed + 1))
  fi
done

echo ""

# =============================================================================
# Section 2: Configuration Validation
# =============================================================================
echo "${BLUE}[2/7] Validating Configuration Files${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check JSON syntax
if jq empty config/repositories.json 2>/dev/null; then
  echo "  ${CHECK} repositories.json has valid JSON syntax"
  passed=$((passed + 1))
else
  echo "  ${CROSS} repositories.json has invalid JSON syntax"
  failed=$((failed + 1))
fi

if jq empty config/schema.json 2>/dev/null; then
  echo "  ${CHECK} schema.json has valid JSON syntax"
  passed=$((passed + 1))
else
  echo "  ${CROSS} schema.json has invalid JSON syntax"
  failed=$((failed + 1))
fi

# Run schema validation if ajv is available
if command -v ajv &>/dev/null; then
  if ajv validate -s config/schema.json -d config/repositories.json --strict=false 2>&1 >/dev/null; then
    echo "  ${CHECK} repositories.json passes schema validation"
    passed=$((passed + 1))
  else
    echo "  ${CROSS} repositories.json fails schema validation"
    failed=$((failed + 1))
  fi
else
  echo "  ${WARN} ajv-cli not installed, skipping schema validation"
  echo "      Install: npm install -g ajv-cli ajv-formats"
  warnings=$((warnings + 1))
fi

echo ""

# =============================================================================
# Section 3: Bash Script Validation
# =============================================================================
echo "${BLUE}[3/7] Validating Bash Scripts${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for script in scripts/*.sh .docker/setup-secrets.sh; do
  if [ ! -f "$script" ]; then
    continue
  fi

  # Check syntax
  if bash -n "$script" 2>/dev/null; then
    echo "  ${CHECK} $script (syntax valid)"
    passed=$((passed + 1))
  else
    echo "  ${CROSS} $script (syntax errors)"
    bash -n "$script" 2>&1 | head -5
    failed=$((failed + 1))
  fi

  # Check shebang
  if head -n 1 "$script" | grep -q "^#!/usr/bin/env bash"; then
    : # Correct shebang, no output
  elif head -n 1 "$script" | grep -q "^#!/bin/bash"; then
    echo "      ${WARN} Uses #!/bin/bash instead of #!/usr/bin/env bash"
    warnings=$((warnings + 1))
  fi

  # Check for set -euo pipefail
  if grep -q "^set -euo pipefail" "$script"; then
    : # Correct, no output
  else
    echo "      ${WARN} Missing 'set -euo pipefail'"
    warnings=$((warnings + 1))
  fi
done

echo ""

# =============================================================================
# Section 4: Workflow File Validation
# =============================================================================
echo "${BLUE}[4/7] Validating GitHub Actions Workflows${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check YAML syntax if yamllint is available
if command -v yamllint &>/dev/null; then
  for workflow in .github/workflows/*.yml; do
    if yamllint -d relaxed "$workflow" &>/dev/null; then
      echo "  ${CHECK} $(basename "$workflow") (YAML valid)"
      passed=$((passed + 1))
    else
      echo "  ${CROSS} $(basename "$workflow") (YAML errors)"
      yamllint -d relaxed "$workflow" 2>&1 | head -5
      failed=$((failed + 1))
    fi
  done
else
  echo "  ${WARN} yamllint not installed, skipping YAML validation"
  echo "      Install: pip install yamllint"
  warnings=$((warnings + 1))
fi

# Check for critical security fixes in publish-upm.yml
echo ""
echo "  Checking for security fixes in publish-upm.yml:"

if grep -q "UPM_REGISTRY.*vars.UPM_REGISTRY" .github/workflows/publish-upm.yml; then
  echo "    ${CHECK} Configurable registry URL"
  passed=$((passed + 1))
else
  echo "    ${CROSS} Missing configurable registry URL"
  failed=$((failed + 1))
fi

if grep -q 'if \[\[ "\$package_name" =~ \[\^a-zA-Z0-9._-\] \]\]' .github/workflows/publish-upm.yml; then
  echo "    ${CHECK} Package name validation (dangerous characters)"
  passed=$((passed + 1))
else
  echo "    ${CROSS} Missing package name validation (dangerous characters)"
  failed=$((failed + 1))
fi

if grep -q "trap.*EXIT ERR INT TERM" .github/workflows/publish-upm.yml; then
  echo "    ${CHECK} Trap-based cleanup"
  passed=$((passed + 1))
else
  echo "    ${CROSS} Missing trap-based cleanup"
  failed=$((failed + 1))
fi

if grep -q "audit-log.json" .github/workflows/publish-upm.yml; then
  echo "    ${CHECK} Audit logging"
  passed=$((passed + 1))
else
  echo "    ${CROSS} Missing audit logging"
  failed=$((failed + 1))
fi

echo ""

# =============================================================================
# Section 5: Docker Configuration Validation
# =============================================================================
echo "${BLUE}[5/7] Validating Docker Configuration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f ".docker/docker-compose.runners.yml" ]; then
  # Check for Docker secrets instead of env vars
  if grep -q "secrets:" .docker/docker-compose.runners.yml && \
     grep -q "github_pat:" .docker/docker-compose.runners.yml; then
    echo "  ${CHECK} Using Docker secrets for credentials"
    passed=$((passed + 1))
  else
    echo "  ${CROSS} Not using Docker secrets for credentials"
    failed=$((failed + 1))
  fi

  # Check Docker socket is NOT mounted (uncommented)
  if grep "^[^#]*- /var/run/docker.sock:/var/run/docker.sock" .docker/docker-compose.runners.yml >/dev/null 2>&1; then
    echo "  ${CROSS} Docker socket is mounted (security risk)"
    failed=$((failed + 1))
  else
    echo "  ${CHECK} Docker socket not mounted (commented or removed)"
    passed=$((passed + 1))
  fi

  # Check secrets file exists
  if [ -f ".docker/.secrets/github_pat" ]; then
    echo "  ${CHECK} Secrets file exists"

    # Check permissions
    perms=$(stat -c "%a" .docker/.secrets/github_pat 2>/dev/null || stat -f "%A" .docker/.secrets/github_pat 2>/dev/null)
    if [ "$perms" = "600" ]; then
      echo "      ${CHECK} Correct permissions (600)"
      passed=$((passed + 1))
    else
      echo "      ${WARN} Permissions are $perms (should be 600)"
      warnings=$((warnings + 1))
    fi
  else
    echo "  ${WARN} Secrets file not found (.docker/.secrets/github_pat)"
    echo "      Run: .docker/setup-secrets.sh"
    warnings=$((warnings + 1))
  fi

  # Test docker compose config
  if command -v docker &>/dev/null; then
    if docker compose -f .docker/docker-compose.runners.yml config &>/dev/null; then
      echo "  ${CHECK} Docker Compose configuration valid"
      passed=$((passed + 1))
    else
      echo "  ${CROSS} Docker Compose configuration invalid"
      failed=$((failed + 1))
    fi
  else
    echo "  ${WARN} Docker not installed, skipping compose validation"
    warnings=$((warnings + 1))
  fi
else
  echo "  ${INFO} Docker configuration not found (optional)"
fi

echo ""

# =============================================================================
# Section 6: Security Checks
# =============================================================================
echo "${BLUE}[6/7] Security Checks${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for hardcoded credentials
echo "  Scanning for potential hardcoded credentials..."
if grep -r -i "password\s*=\|token\s*=\|secret\s*=\|key\s*=" \
  --include="*.yml" --include="*.yaml" --include="*.sh" --include="*.json" \
  --exclude-dir=".git" --exclude-dir="node_modules" . 2>/dev/null | grep -v "ACCESS_TOKEN_FILE"; then
  echo "    ${WARN} Found potential hardcoded credentials (review above)"
  warnings=$((warnings + 1))
else
  echo "    ${CHECK} No hardcoded credentials found"
  passed=$((passed + 1))
fi

# Check for sed usage (should use regex instead)
echo "  Checking for unsafe sed usage..."
if grep -r "sed.*github.com" scripts/ .github/ 2>/dev/null | grep -v "Binary\|\.backup"; then
  echo "    ${WARN} Found sed usage for URL parsing (should use regex)"
  warnings=$((warnings + 1))
else
  echo "    ${CHECK} No unsafe sed usage found"
  passed=$((passed + 1))
fi

# Check for unquoted variables in scripts
echo "  Checking for unquoted variables in critical paths..."
if grep -r 'cd \$[a-zA-Z_]' scripts/ .github/ 2>/dev/null | grep -v '"' | grep -v "Binary"; then
  echo "    ${WARN} Found unquoted variables in cd commands"
  warnings=$((warnings + 1))
else
  echo "    ${CHECK} Variables properly quoted"
  passed=$((passed + 1))
fi

echo ""

# =============================================================================
# Section 7: GitHub CLI & Dependencies
# =============================================================================
echo "${BLUE}[7/7] Checking Dependencies${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

dependencies=(
  "gh:GitHub CLI"
  "jq:JSON processor"
  "git:Version control"
  "curl:HTTP client"
  "npm:Node package manager"
)

for dep in "${dependencies[@]}"; do
  cmd="${dep%%:*}"
  name="${dep##*:}"

  if command -v "$cmd" &>/dev/null; then
    version=$("$cmd" --version 2>&1 | head -1)
    echo "  ${CHECK} $name ($version)"
    passed=$((passed + 1))
  else
    echo "  ${CROSS} $name not installed"
    failed=$((failed + 1))
  fi
done

# Check GitHub authentication
if command -v gh &>/dev/null; then
  if gh auth status &>/dev/null; then
    echo "  ${CHECK} GitHub CLI authenticated"
    passed=$((passed + 1))
  else
    echo "  ${WARN} GitHub CLI not authenticated (run: gh auth login)"
    warnings=$((warnings + 1))
  fi
fi

# Optional dependencies
echo ""
echo "  Optional dependencies:"
optional_deps=(
  "ajv:JSON schema validator"
  "yamllint:YAML linter"
  "shellcheck:Shell script analyzer"
)

for dep in "${optional_deps[@]}"; do
  cmd="${dep%%:*}"
  name="${dep##*:}"

  if command -v "$cmd" &>/dev/null; then
    echo "    ${CHECK} $name"
  else
    echo "    ${INFO} $name not installed (optional)"
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Validation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  ${CHECK} Passed:   $passed"
echo "  ${CROSS} Failed:   $failed"
echo "  ${WARN} Warnings: $warnings"
echo ""

if [ "$failed" -eq 0 ]; then
  if [ "$warnings" -eq 0 ]; then
    echo "${GREEN}✅ All checks passed! System is ready for production deployment.${NC}"
    echo ""
    exit 0
  else
    echo "${YELLOW}⚠️  All critical checks passed, but there are $warnings warning(s).${NC}"
    echo "    Review warnings above before deploying."
    echo ""
    exit 0
  fi
else
  echo "${RED}❌ Validation failed with $failed error(s).${NC}"
  echo "   Fix the errors above before deploying to production."
  echo ""
  exit 1
fi
