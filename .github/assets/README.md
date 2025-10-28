# Assets Directory

This directory contains assets used across the UPMAutoPublisher system.

## Logo File

**File:** `the1studio-logo.png`
**Purpose:** Used in Discord notifications for all UPM Auto Publisher workflows
**Recommended Size:** 256x256 pixels (or smaller, Discord will resize)
**Format:** PNG with transparency preferred

### Where It's Used

The logo appears in Discord notifications for:
- Package cache builds (build-package-cache.yml)
- Daily health audits (daily-audit.yml)
- Stale package publishing (trigger-stale-publishes.yml)
- Repository monitoring (monitor-publishes.yml)
- Individual package publishes (publish-upm.yml in target repos)

### How to Update

1. Place your logo file here as `the1studio-logo.png`
2. Commit and push to master
3. Discord will automatically use it in all notifications

### Technical Details

The logo is referenced in workflows using GitHub's raw content URL:
```
https://raw.githubusercontent.com/The1Studio/UPMAutoPublisher/master/.github/assets/the1studio-logo.png
```

This URL is stable and will always point to the latest version of the logo.
