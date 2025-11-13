# UPMAutoPublisher - Refactoring Plan

**Date:** 2025-11-13
**Purpose:** Eliminate duplication and hardcoding across the project
**Status:** 🚧 In Progress

---

## 📋 Issues Identified

### 1. Hardcoded Discord Thread IDs
- **Packages Thread:** `1437635998509957181` (6 occurrences)
- **Monitoring Thread:** `1437635908781342783` (5 occurrences)
- **Impact:** Difficult to change, error-prone
- **Solution:** Move to organization variables

### 2. Inconsistent Runner Configuration
- **Pattern 1:** Direct self-hosted (11 workflows)
- **Pattern 2:** With fallback (5 workflows)
- **Pattern 3:** Always ubuntu-latest (3 workflows)
- **Impact:** Inconsistent behavior, hard to manage
- **Solution:** Standardize to Pattern 2 everywhere

### 3. Duplicated Discord Notification Code
- **Occurrences:** 8+ workflows
- **Lines Duplicated:** ~50-100 lines per workflow
- **Total Duplication:** 400-800 lines
- **Impact:** Maintenance nightmare, inconsistency risk
- **Solution:** Create reusable composite action

### 4. Duplicated APT Fix Code
- **Occurrences:** 5+ workflows
- **Lines Duplicated:** ~8 lines per workflow
- **Total Duplication:** 40+ lines
- **Impact:** Repetitive, error-prone
- **Solution:** Create composite action

### 5. Hardcoded Configuration Values
- Discord colors (3 values)
- Gemini temperatures (2 values)
- Token limits (2 values)
- Icon URLs (2 values)
- Timeouts (6 different values)

---

## 🎯 Refactoring Strategy

### Phase 1: Organization Variables (PRIORITY 1)
**Create these GitHub Organization Variables:**

```bash
# Discord Thread IDs
DISCORD_THREAD_PACKAGES="1437635998509957181"
DISCORD_THREAD_MONITORING="1437635908781342783"

# Discord Visual Assets
DISCORD_ICON_NPM="https://raw.githubusercontent.com/github/explore/80688e429a7d4ef2fca1e82350fe8e3517d3494d/topics/npm/npm.png"
DISCORD_ICON_STUDIO="https://raw.githubusercontent.com/The1Studio/UPMAutoPublisher/master/.github/assets/the1studio-logo.png"

# Discord Colors (as strings since vars only support strings)
DISCORD_COLOR_SUCCESS="4764443"
DISCORD_COLOR_FAILURE="15158332"
DISCORD_COLOR_WARNING="16776960"

# Gemini API Configuration
GEMINI_TEMP_CHANGELOG="0.2"
GEMINI_TEMP_VALIDATION="0.1"
GEMINI_TOKENS_CHANGELOG="1024"
GEMINI_TOKENS_VALIDATION="2048"

# Workflow Timeouts (minutes)
TIMEOUT_DEFAULT="30"
TIMEOUT_VALIDATION="60"
TIMEOUT_QUICK="10"
```

**Commands to create:**
```bash
gh variable set DISCORD_THREAD_PACKAGES --body "1437635998509957181" --org The1Studio
gh variable set DISCORD_THREAD_MONITORING --body "1437635908781342783" --org The1Studio
gh variable set DISCORD_ICON_NPM --body "https://raw.githubusercontent.com/github/explore/80688e429a7d4ef2fca1e82350fe8e3517d3494d/topics/npm/npm.png" --org The1Studio
gh variable set DISCORD_ICON_STUDIO --body "https://raw.githubusercontent.com/The1Studio/UPMAutoPublisher/master/.github/assets/the1studio-logo.png" --org The1Studio
gh variable set DISCORD_COLOR_SUCCESS --body "4764443" --org The1Studio
gh variable set DISCORD_COLOR_FAILURE --body "15158332" --org The1Studio
gh variable set DISCORD_COLOR_WARNING --body "16776960" --org The1Studio
```

### Phase 2: Create Composite Actions

#### 2.1 Discord Notification Action
**File:** `.github/actions/discord-notify/action.yml`

**Inputs:**
- `webhook-url` (required)
- `thread-id` (required)
- `title` (required)
- `description` (required)
- `status` (required: success/failure/warning)
- `fields` (optional: JSON array)
- `workflow-url` (auto-populated)

**Benefits:**
- Eliminates 400-800 lines of duplication
- Single source of truth for Discord formatting
- Easy to update notification style globally

#### 2.2 APT Fix Action
**File:** `.github/actions/apt-fix/action.yml`

**Purpose:**
- Fix APT sources for ARC runners (port 80 blocked)
- Install common dependencies

**Benefits:**
- Eliminates 40+ lines of duplication
- Consistent APT configuration

### Phase 3: Standardize Runner Configuration

**Replace all patterns with:**
```yaml
runs-on: ${{ vars.USE_SELF_HOSTED_RUNNERS != 'false' && fromJSON('["self-hosted", "arc", "the1studio", "org"]') || 'ubuntu-latest' }}
```

**Affected Workflows:**
1. daily-package-check.yml
2. publish-upm.yml
3. publish-unpublished.yml
4. trigger-stale-publishes.yml
5. build-package-cache.yml
6. validate-all-packages.yml
7. daily-audit.yml
8. monitor-publishes.yml
9. register-repos.yml
10. sync-repo-status.yml
11. upm-publish-dispatcher.yml

### Phase 4: Update All Workflows

**For each workflow:**
1. Replace hardcoded Discord thread IDs with `${{ vars.DISCORD_THREAD_* }}`
2. Replace runner config with standardized pattern
3. Replace Discord notification code with composite action
4. Replace APT fix code with composite action (if applicable)
5. Replace hardcoded timeouts with variables
6. Test workflow still works

---

## 📝 Implementation Checklist

### Phase 1: Setup (Completed First)
- [ ] Create all organization variables
- [ ] Verify variables are accessible
- [ ] Document variable usage

### Phase 2: Create Composite Actions
- [ ] Create `.github/actions/discord-notify/action.yml`
- [ ] Create `.github/actions/apt-fix/action.yml`
- [ ] Test both actions in a sample workflow

### Phase 3: Update Workflows (Do in Order)

#### Package-Related Workflows (Use DISCORD_THREAD_PACKAGES)
- [ ] publish-upm.yml
- [ ] publish-unpublished.yml
- [ ] trigger-stale-publishes.yml
- [ ] handle-publish-request.yml

#### Monitoring Workflows (Use DISCORD_THREAD_MONITORING)
- [ ] daily-package-check.yml
- [ ] build-package-cache.yml
- [ ] validate-all-packages.yml
- [ ] daily-audit.yml
- [ ] monitor-publishes.yml

#### Other Workflows
- [ ] register-repos.yml
- [ ] sync-repo-status.yml
- [ ] manual-register-repo.yml
- [ ] upm-publish-dispatcher.yml

### Phase 4: Testing
- [ ] Test each workflow after refactoring
- [ ] Verify Discord notifications still work
- [ ] Verify runner selection works
- [ ] Check for any regressions

### Phase 5: Documentation
- [ ] Update CLAUDE.md with new patterns
- [ ] Document composite actions
- [ ] Update troubleshooting guide
- [ ] Create migration notes

---

## 🔧 Implementation Details

### Discord Notification Composite Action

**Structure:**
```yaml
name: 'Discord Notification'
description: 'Send formatted Discord webhook notification'
inputs:
  webhook-url:
    description: 'Discord webhook URL'
    required: true
  thread-id:
    description: 'Discord thread ID'
    required: true
  title:
    description: 'Notification title'
    required: true
  description:
    description: 'Notification description'
    required: true
  status:
    description: 'Status (success/failure/warning)'
    required: true
    default: 'success'
  fields:
    description: 'JSON array of embed fields'
    required: false
    default: '[]'
runs:
  using: 'composite'
  steps:
    - shell: bash
      env:
        WEBHOOK_URL: ${{ inputs.webhook-url }}
        THREAD_ID: ${{ inputs.thread-id }}
        TITLE: ${{ inputs.title }}
        DESCRIPTION: ${{ inputs.description }}
        STATUS: ${{ inputs.status }}
        FIELDS: ${{ inputs.fields }}
      run: |
        # Determine color based on status
        case "$STATUS" in
          success)
            color="${{ vars.DISCORD_COLOR_SUCCESS }}"
            emoji="✅"
            ;;
          failure)
            color="${{ vars.DISCORD_COLOR_FAILURE }}"
            emoji="❌"
            ;;
          *)
            color="${{ vars.DISCORD_COLOR_WARNING }}"
            emoji="⚠️"
            ;;
        esac

        # Generate payload
        jq -n \
          --arg title "$emoji $TITLE" \
          --arg desc "$DESCRIPTION" \
          --argjson color "$color" \
          --argjson fields "$FIELDS" \
          '{
            "embeds": [{
              "title": $title,
              "description": $desc,
              "color": $color,
              "fields": $fields,
              "timestamp": (now | todate)
            }]
          }' > payload.json

        # Send to Discord
        curl -X POST "$WEBHOOK_URL?thread_id=$THREAD_ID" \
          -H "Content-Type: application/json" \
          -d @payload.json
```

### APT Fix Composite Action

**Structure:**
```yaml
name: 'Fix APT Sources'
description: 'Fix APT sources for ARC runners (port 80 blocked)'
runs:
  using: 'composite'
  steps:
    - shell: bash
      run: |
        # Fix APT sources to use HTTPS
        sudo sed -i 's|http://archive.ubuntu.com|https://archive.ubuntu.com|g' /etc/apt/sources.list
        sudo sed -i 's|http://security.ubuntu.com|https://security.ubuntu.com|g' /etc/apt/sources.list

        # Disable PPA repositories
        sudo mv /etc/apt/sources.list.d /etc/apt/sources.list.d.bak 2>/dev/null || true
        sudo mkdir -p /etc/apt/sources.list.d

        # Update package lists
        sudo apt-get update -qq
```

---

## 📊 Expected Impact

### Code Reduction
- **Before:** ~5000 lines across 13 workflows
- **After:** ~3500 lines (30% reduction)
- **Duplication Eliminated:** 400-800 lines of Discord code + 40+ lines of APT fixes

### Maintainability
- **Discord Notifications:** Change once, apply everywhere
- **APT Fixes:** Single source of truth
- **Configuration:** Centralized in organization variables
- **Testing:** Easier to test composite actions

### Consistency
- All workflows use same notification format
- All workflows use same runner selection logic
- All workflows use same APT fix procedure
- All hardcoded values moved to variables

---

## ⚠️ Risks & Mitigation

### Risk 1: Breaking Changes
**Mitigation:** Test each workflow after changes, roll back if needed

### Risk 2: Variable Access Issues
**Mitigation:** Verify variables are accessible before refactoring

### Risk 3: Composite Action Bugs
**Mitigation:** Test composite actions thoroughly in sample workflow first

### Risk 4: Discord Format Changes
**Mitigation:** Keep old format as comment in action for reference

---

## 🚀 Rollout Plan

### Step 1: Preparation (Day 1)
1. Create organization variables
2. Create composite actions
3. Test in sample workflow

### Step 2: Phase 1 Rollout (Day 2)
1. Update 4 package-related workflows
2. Test each workflow
3. Monitor for issues

### Step 3: Phase 2 Rollout (Day 3)
1. Update 5 monitoring workflows
2. Test each workflow
3. Monitor for issues

### Step 4: Phase 3 Rollout (Day 4)
1. Update remaining workflows
2. Final testing
3. Update documentation

### Step 5: Cleanup (Day 5)
1. Remove old commented code
2. Update all documentation
3. Create migration guide

---

## 📚 Documentation Updates Needed

1. **CLAUDE.md**
   - Document new composite actions
   - Update examples to use variables
   - Document organization variables

2. **docs/configuration.md**
   - Add section on organization variables
   - Document composite action usage
   - Update troubleshooting section

3. **docs/architecture-decisions.md**
   - Document refactoring decisions
   - Explain composite action benefits
   - Document variable strategy

4. **README.md**
   - Update setup instructions
   - Document new requirements
   - Update examples

---

**Status:** Ready to implement
**Estimated Time:** 4-5 days
**Risk Level:** Medium (breaking changes possible)
**Benefits:** High (30% code reduction, much easier maintenance)
