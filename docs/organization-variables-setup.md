# Organization Variables Setup Guide

**Date:** 2025-11-13
**Purpose:** Centralize hardcoded values into GitHub Organization Variables
**Repository:** The1Studio/UPMAutoPublisher

---

## 📋 Overview

This guide documents all organization variables needed for the UPMAutoPublisher system to eliminate hardcoded values and improve maintainability.

---

## 🔧 Required Organization Variables

### Discord Configuration

#### 1. Discord Thread IDs

**DISCORD_THREAD_PACKAGES**
- **Value:** `1437635998509957181`
- **Purpose:** Thread for package publish notifications
- **Used by:** publish-upm.yml, publish-unpublished.yml, trigger-stale-publishes.yml, handle-publish-request.yml
- **Command:**
  ```bash
  gh variable set DISCORD_THREAD_PACKAGES \
    --body "1437635998509957181" \
    --org The1Studio
  ```

**DISCORD_THREAD_MONITORING**
- **Value:** `1437635908781342783`
- **Purpose:** Thread for monitoring/daily job notifications
- **Used by:** daily-package-check.yml, build-package-cache.yml, validate-all-packages.yml, daily-audit.yml, monitor-publishes.yml
- **Command:**
  ```bash
  gh variable set DISCORD_THREAD_MONITORING \
    --body "1437635908781342783" \
    --org The1Studio
  ```

#### 2. Discord Visual Assets

**DISCORD_ICON_NPM**
- **Value:** `https://raw.githubusercontent.com/github/explore/80688e429a7d4ef2fca1e82350fe8e3517d3494d/topics/npm/npm.png`
- **Purpose:** NPM icon for Discord embeds author section
- **Used by:** All workflows with Discord notifications
- **Command:**
  ```bash
  gh variable set DISCORD_ICON_NPM \
    --body "https://raw.githubusercontent.com/github/explore/80688e429a7d4ef2fca1e82350fe8e3517d3494d/topics/npm/npm.png" \
    --org The1Studio
  ```

**DISCORD_ICON_STUDIO**
- **Value:** `https://raw.githubusercontent.com/The1Studio/UPMAutoPublisher/master/.github/assets/the1studio-logo.png`
- **Purpose:** The1Studio logo for Discord embeds footer
- **Used by:** All workflows with Discord notifications
- **Command:**
  ```bash
  gh variable set DISCORD_ICON_STUDIO \
    --body "https://raw.githubusercontent.com/The1Studio/UPMAutoPublisher/master/.github/assets/the1studio-logo.png" \
    --org The1Studio
  ```

#### 3. Discord Colors

**DISCORD_COLOR_SUCCESS**
- **Value:** `4764443`
- **Purpose:** Green color for successful workflow notifications
- **Hex:** `#48C0B3` (Discord decimal format)
- **Command:**
  ```bash
  gh variable set DISCORD_COLOR_SUCCESS \
    --body "4764443" \
    --org The1Studio
  ```

**DISCORD_COLOR_FAILURE**
- **Value:** `15158332`
- **Purpose:** Red color for failed workflow notifications
- **Hex:** `#E74C3C` (Discord decimal format)
- **Command:**
  ```bash
  gh variable set DISCORD_COLOR_FAILURE \
    --body "15158332" \
    --org The1Studio
  ```

**DISCORD_COLOR_WARNING**
- **Value:** `16776960`
- **Purpose:** Yellow color for warning/cancelled workflow notifications
- **Hex:** `#FFFF00` (Discord decimal format)
- **Command:**
  ```bash
  gh variable set DISCORD_COLOR_WARNING \
    --body "16776960" \
    --org The1Studio
  ```

### Gemini API Configuration

**GEMINI_TEMP_CHANGELOG**
- **Value:** `0.2`
- **Purpose:** Temperature for Gemini changelog generation (balanced creativity)
- **Used by:** generate-changelog.sh
- **Command:**
  ```bash
  gh variable set GEMINI_TEMP_CHANGELOG \
    --body "0.2" \
    --org The1Studio
  ```

**GEMINI_TEMP_VALIDATION**
- **Value:** `0.1`
- **Purpose:** Temperature for Gemini package.json validation (deterministic)
- **Used by:** handle-publish-request.yml validation step
- **Command:**
  ```bash
  gh variable set GEMINI_TEMP_VALIDATION \
    --body "0.1" \
    --org The1Studio
  ```

**GEMINI_TOKENS_CHANGELOG**
- **Value:** `1024`
- **Purpose:** Max output tokens for changelog generation
- **Used by:** generate-changelog.sh
- **Command:**
  ```bash
  gh variable set GEMINI_TOKENS_CHANGELOG \
    --body "1024" \
    --org The1Studio
  ```

**GEMINI_TOKENS_VALIDATION**
- **Value:** `2048`
- **Purpose:** Max output tokens for package.json validation
- **Used by:** handle-publish-request.yml validation step
- **Command:**
  ```bash
  gh variable set GEMINI_TOKENS_VALIDATION \
    --body "2048" \
    --org The1Studio
  ```

### Workflow Timeouts

**TIMEOUT_DEFAULT**
- **Value:** `30`
- **Purpose:** Default timeout for most workflows (minutes)
- **Used by:** Multiple workflows
- **Command:**
  ```bash
  gh variable set TIMEOUT_DEFAULT \
    --body "30" \
    --org The1Studio
  ```

**TIMEOUT_VALIDATION**
- **Value:** `60`
- **Purpose:** Extended timeout for validation workflows (minutes)
- **Used by:** validate-all-packages.yml
- **Command:**
  ```bash
  gh variable set TIMEOUT_VALIDATION \
    --body "60" \
    --org The1Studio
  ```

**TIMEOUT_QUICK**
- **Value:** `10`
- **Purpose:** Short timeout for quick checks (minutes)
- **Used by:** monitor-publishes.yml, daily-package-check.yml
- **Command:**
  ```bash
  gh variable set TIMEOUT_QUICK \
    --body "10" \
    --org The1Studio
  ```

---

## 🚀 Bulk Setup Script

Copy and paste this script to set up all variables at once:

```bash
#!/bin/bash
# Setup all UPMAutoPublisher organization variables

ORG="The1Studio"

echo "🔧 Setting up organization variables for $ORG..."

# Discord Thread IDs
gh variable set DISCORD_THREAD_PACKAGES --body "1437635998509957181" --org $ORG
gh variable set DISCORD_THREAD_MONITORING --body "1437635908781342783" --org $ORG

# Discord Visual Assets
gh variable set DISCORD_ICON_NPM --body "https://raw.githubusercontent.com/github/explore/80688e429a7d4ef2fca1e82350fe8e3517d3494d/topics/npm/npm.png" --org $ORG
gh variable set DISCORD_ICON_STUDIO --body "https://raw.githubusercontent.com/The1Studio/UPMAutoPublisher/master/.github/assets/the1studio-logo.png" --org $ORG

# Discord Colors
gh variable set DISCORD_COLOR_SUCCESS --body "4764443" --org $ORG
gh variable set DISCORD_COLOR_FAILURE --body "15158332" --org $ORG
gh variable set DISCORD_COLOR_WARNING --body "16776960" --org $ORG

# Gemini API Configuration
gh variable set GEMINI_TEMP_CHANGELOG --body "0.2" --org $ORG
gh variable set GEMINI_TEMP_VALIDATION --body "0.1" --org $ORG
gh variable set GEMINI_TOKENS_CHANGELOG --body "1024" --org $ORG
gh variable set GEMINI_TOKENS_VALIDATION --body "2048" --org $ORG

# Workflow Timeouts
gh variable set TIMEOUT_DEFAULT --body "30" --org $ORG
gh variable set TIMEOUT_VALIDATION --body "60" --org $ORG
gh variable set TIMEOUT_QUICK --body "10" --org $ORG

echo "✅ All organization variables set successfully!"

# Verify variables
echo ""
echo "📋 Verifying variables..."
gh variable list --org $ORG | grep -E "DISCORD|GEMINI|TIMEOUT"
```

**Save as:** `scripts/setup-org-variables.sh`

**Run with:**
```bash
chmod +x scripts/setup-org-variables.sh
./scripts/setup-org-variables.sh
```

---

## ✅ Verification

After setting up variables, verify they are accessible:

```bash
# List all organization variables
gh variable list --org The1Studio

# Check specific variable
gh variable get DISCORD_THREAD_PACKAGES --org The1Studio
```

Expected output should show all 14 variables.

---

## 📝 Usage in Workflows

### Accessing Variables

**In workflow YAML:**
```yaml
env:
  THREAD_ID: ${{ vars.DISCORD_THREAD_PACKAGES }}
  COLOR_SUCCESS: ${{ vars.DISCORD_COLOR_SUCCESS }}
```

**In composite actions:**
```yaml
env:
  COLOR: ${DISCORD_COLOR_SUCCESS:-4764443}  # Fallback if var not set
```

### Example Workflow Update

**Before (hardcoded):**
```yaml
- name: Send Discord notification
  env:
    DISCORD_WEBHOOK: ${{ secrets.DISCORD_WEBHOOK_UPM }}
    DISCORD_THREAD_ID: "1437635998509957181"
  run: |
    color=4764443  # Green
```

**After (using variables):**
```yaml
- name: Send Discord notification
  env:
    DISCORD_WEBHOOK: ${{ secrets.DISCORD_WEBHOOK_UPM }}
    DISCORD_THREAD_ID: ${{ vars.DISCORD_THREAD_PACKAGES }}
  run: |
    color="${{ vars.DISCORD_COLOR_SUCCESS }}"
```

---

## 🔄 Updating Variables

To update a variable value:

```bash
gh variable set VARIABLE_NAME --body "new_value" --org The1Studio
```

**Example:**
```bash
# Change validation timeout from 60 to 90 minutes
gh variable set TIMEOUT_VALIDATION --body "90" --org The1Studio
```

**Note:** Variable changes take effect immediately for new workflow runs.

---

## 🗑️ Removing Variables

To remove a variable (not recommended unless deprecating):

```bash
gh variable delete VARIABLE_NAME --org The1Studio
```

---

## 📊 Variable Dependency Matrix

| Variable | Used By (Workflows/Scripts) | Count |
|----------|----------------------------|-------|
| DISCORD_THREAD_PACKAGES | 6 workflows | 6 |
| DISCORD_THREAD_MONITORING | 5 workflows | 5 |
| DISCORD_COLOR_SUCCESS | All Discord workflows | 11 |
| DISCORD_COLOR_FAILURE | All Discord workflows | 11 |
| DISCORD_COLOR_WARNING | All Discord workflows | 11 |
| DISCORD_ICON_NPM | All Discord workflows | 11 |
| DISCORD_ICON_STUDIO | All Discord workflows | 11 |
| GEMINI_TEMP_CHANGELOG | generate-changelog.sh | 1 |
| GEMINI_TEMP_VALIDATION | handle-publish-request.yml | 1 |
| GEMINI_TOKENS_CHANGELOG | generate-changelog.sh | 1 |
| GEMINI_TOKENS_VALIDATION | handle-publish-request.yml | 1 |
| TIMEOUT_DEFAULT | 7 workflows | 7 |
| TIMEOUT_VALIDATION | 1 workflow | 1 |
| TIMEOUT_QUICK | 2 workflows | 2 |

---

## 🛡️ Security Considerations

### Variables vs Secrets

**Organization Variables:**
- ✅ Non-sensitive configuration
- ✅ Visible in workflow logs
- ✅ Can be changed without re-triggering workflows
- ✅ Examples: Thread IDs, colors, URLs, timeouts

**Organization Secrets:**
- 🔒 Sensitive credentials
- 🔒 Hidden in logs
- 🔒 Examples: API keys, tokens, webhooks

**Current Secrets (unchanged):**
- `DISCORD_WEBHOOK_UPM`
- `GEMINI_API_KEY`
- `GH_PAT`
- `NPM_TOKEN`

### Best Practices

1. **Never store sensitive data in variables**
2. **Use descriptive variable names**
3. **Document all variables**
4. **Test changes in staging first**
5. **Keep variable values in version control (this doc)**

---

## 🔧 Troubleshooting

### Issue: Variable not found

**Symptom:**
```
Error: Unable to process variable: Variable not found
```

**Solution:**
```bash
# Verify variable exists
gh variable list --org The1Studio | grep VARIABLE_NAME

# If missing, set it
gh variable set VARIABLE_NAME --body "value" --org The1Studio
```

### Issue: Wrong variable value

**Symptom:** Workflow uses old/incorrect value

**Solution:**
```bash
# Check current value
gh variable get VARIABLE_NAME --org The1Studio

# Update if wrong
gh variable set VARIABLE_NAME --body "correct_value" --org The1Studio

# Re-run workflow
```

### Issue: Permission denied

**Symptom:**
```
Error: Resource not accessible by personal access token
```

**Solution:**
Ensure your GitHub token has `admin:org` scope for managing organization variables.

---

## 📚 Related Documentation

- [GitHub Variables Documentation](https://docs.github.com/en/actions/learn-github-actions/variables)
- [Composite Actions Guide](.github/actions/README.md) (to be created)
- [Refactoring Plan](./refactoring-plan.md)
- [Configuration Guide](./configuration.md)

---

**Last Updated:** 2025-11-13
**Maintainer:** The1Studio DevOps Team
**Status:** ✅ Ready for implementation
