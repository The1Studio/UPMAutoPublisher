# UPM Auto Publisher - Workflow System Overview

## 📊 Total Workflows: 13

## 🔄 Core Publishing System (5 workflows)

### 1. **publish-upm.yml** - Template for Target Repositories
- **Location**: Copied to target repos (UITemplate, UnityBuildScript, etc.)
- **Trigger**: On push to master/main when package.json changes
- **Purpose**: Detects package.json changes and dispatches publish request
- **Action**: Sends repository_dispatch to UPMAutoPublisher

### 2. **upm-publish-dispatcher.yml** - Target Repo Dispatcher
- **Location**: In target repositories
- **Trigger**: On push to master/main when package.json changes
- **Purpose**: Lightweight dispatcher that sends repository_dispatch events
- **Action**: Triggers handle-publish-request.yml in UPMAutoPublisher

### 3. **handle-publish-request.yml** - Main Publishing Engine ⭐
- **Location**: UPMAutoPublisher
- **Trigger**: repository_dispatch (package_publish event)
- **Purpose**: Core publishing logic - clones repo, detects packages, publishes to registry
- **Features**:
  - Auto-detects changed package.json files
  - Version validation & rollback prevention
  - NPM publish to upm.the1studio.org
  - Beautiful Discord notifications (thread: 1437635998509957181)
  - Audit logging
- **Discord**: ✅ Beautified with emojis, version change detection (🔴 MAJOR, 🟡 MINOR, 🟢 PATCH)

### 4. **publish-unpublished.yml** - Catch Missed Publishes
- **Trigger**: Schedule (every 2 hours)
- **Purpose**: Scans all repos for packages that should be published but aren't
- **Action**: Triggers repository_dispatch for repos with unpublished versions

### 5. **trigger-stale-publishes.yml** - Re-trigger Failed Publishes
- **Trigger**: Schedule (every 3 hours)
- **Purpose**: Retries publishing for packages that failed
- **Action**: Triggers repository_dispatch for stale packages

## 📋 Repository Management (3 workflows)

### 6. **manual-register-repo.yml** - Manual Registration
- **Trigger**: workflow_dispatch (manual)
- **Purpose**: Register a new repository to the system
- **Action**: Updates config/repositories.json, creates PR in target repo with workflow

### 7. **register-repos.yml** - Auto-Registration
- **Trigger**: push to master (when config/repositories.json changes)
- **Purpose**: Automatically creates PRs in target repos with workflow files
- **Features**:
  - Copies publish-upm.yml or upm-publish-dispatcher.yml to target repo
  - Creates PR with workflow setup
  - Auto-merge enabled (when CI passes)

### 8. **sync-repo-status.yml** - Status Sync
- **Trigger**: Schedule (daily at 2 AM UTC)
- **Purpose**: Updates repository status in config/repositories.json
- **Action**: Checks if repos are still active/accessible

## 📊 Monitoring & Reporting (3 workflows)

### 9. **daily-package-check.yml** - Daily Report ⭐
- **Trigger**: Schedule (daily at 9 AM UTC / 4 PM UTC+7)
- **Purpose**: Daily report of package version changes
- **Features**:
  - Scans all registered repos
  - Detects version changes in last 24 hours
  - Beautiful Discord notification (thread: 1437635908781342783)
- **Discord**: ✅ Beautified with status icons (✅/📦/⚠️), statistics, error handling

### 10. **monitor-publishes.yml** - Active Monitoring
- **Trigger**: Schedule (every 15 minutes)
- **Purpose**: Monitors ongoing publish workflows across all repos
- **Action**: Tracks workflow status, notifies on issues

### 11. **daily-audit.yml** - Audit Report
- **Trigger**: Schedule (daily at 1 AM UTC)
- **Purpose**: Comprehensive audit of all repositories and packages
- **Action**: Generates audit report, checks for issues

## 🛠️ Maintenance (2 workflows)

### 12. **build-package-cache.yml** - Cache Management
- **Trigger**: Schedule (daily at midnight)
- **Purpose**: Builds cache of all packages for faster lookups
- **Action**: Updates package registry cache

### 13. **test-beautiful-notification.yml** - Testing ⚠️
- **Trigger**: workflow_dispatch (manual)
- **Purpose**: Test beautiful Discord notifications
- **Status**: Can be removed after testing complete

---

## 🔄 Publishing Flow

```
┌─────────────────────────────────────────────────────────────┐
│ Developer pushes package.json change to UITemplate/master  │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ upm-publish-dispatcher.yml (in UITemplate)                  │
│ - Detects package.json change                               │
│ - Sends repository_dispatch to UPMAutoPublisher             │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ handle-publish-request.yml (in UPMAutoPublisher)            │
│ - Clones UITemplate                                          │
│ - Detects changed packages                                   │
│ - Validates versions                                         │
│ - Publishes to upm.the1studio.org                           │
│ - Sends Discord notification (thread: 1437635998509957181)  │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ Package published! Discord notification sent with:          │
│ - 🔧 com.theone.utils: 1.0.7 ➜ 1.0.8 (🟢 PATCH)            │
│ - Registry link                                              │
│ - Commit details                                             │
└─────────────────────────────────────────────────────────────┘
```

## 📅 Scheduled Tasks

| Time (UTC) | Workflow | Purpose |
|------------|----------|---------|
| 00:00 | build-package-cache.yml | Build package cache |
| 01:00 | daily-audit.yml | Daily audit report |
| 02:00 | sync-repo-status.yml | Sync repository status |
| 09:00 | daily-package-check.yml | Daily version check report |
| Every 15 min | monitor-publishes.yml | Monitor active publishes |
| Every 2 hrs | publish-unpublished.yml | Catch missed publishes |
| Every 3 hrs | trigger-stale-publishes.yml | Retry failed publishes |

## 🎨 Discord Notifications

### Thread 1: Publish Notifications (1437635998509957181)
- **Source**: handle-publish-request.yml
- **Trigger**: When packages are published
- **Format**: Beautiful with emojis, version change detection
- **Shows**:
  - 🚀 MAJOR upgrades (red)
  - ✨ MINOR upgrades (yellow)
  - 🔧 PATCH upgrades (green)
  - 🆕 NEW packages
  - Registry links, commit info, workflow links

### Thread 2: Daily Reports (1437635908781342783)
- **Source**: daily-package-check.yml
- **Trigger**: Daily at 9 AM UTC
- **Format**: Beautiful with status icons
- **Shows**:
  - ✅ All Stable / 📦 Updates Detected / ⚠️ Issues Detected
  - Version changes in last 24 hours
  - Repository statistics
  - Errors (if any)

## 🔑 Required Secrets

| Secret | Used By | Purpose |
|--------|---------|---------|
| `NPM_TOKEN` | handle-publish-request.yml | Authenticate to upm.the1studio.org |
| `DISCORD_WEBHOOK_UPM` | handle-publish-request.yml, daily-package-check.yml | Send Discord notifications |
| `GH_PAT` | register-repos.yml, manual-register-repo.yml | Create PRs, trigger workflows |

## 🗂️ Configuration Files

- **config/repositories.json** - Registry of all repositories using auto-publish
- **.github/workflows/** - All workflow definitions
- **scripts/** - Supporting scripts (validation, audit, etc.)

## 📦 Registered Repositories (Example)

1. **The1Studio/UITemplate** ✅
2. **The1Studio/UnityBuildScript** ✅
3. **The1Studio/TheOneFeature**
4. **The1Studio/PlayableLabs**
5. **The1Studio/GameFoundation**
6. And more...

---

## 🎯 Key Features

✅ Automatic package publishing on version bump
✅ Beautiful Discord notifications with emojis
✅ Version change detection (MAJOR/MINOR/PATCH)
✅ Rollback prevention
✅ Daily monitoring and reports
✅ Automatic retry on failures
✅ Comprehensive audit logging
✅ Multi-package support
✅ Registry health checks
✅ Auto-merge PRs when CI passes

## 🚀 Future Enhancements (Optional)

- [ ] Slack integration
- [ ] Email notifications
- [ ] Changelog generation
- [ ] Release notes automation
- [ ] Metrics dashboard
