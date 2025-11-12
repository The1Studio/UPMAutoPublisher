# Changelog Management for UPM Packages

## Overview

This document outlines changelog management strategies for UPM packages in The1Studio organization.

## Current State

- ✅ Packages auto-publish on version bump
- ✅ Discord notifications show version changes
- ✅ Audit logs track all publishes
- ❌ No automated changelog generation
- ❌ No CHANGELOG.md files in packages

## Recommended Approach

### Option 1: Manual CHANGELOG.md (RECOMMENDED)

**Pros:**
- ✅ Simple, immediate
- ✅ Full control over messaging
- ✅ Works with existing workflow
- ✅ Published with package

**Cons:**
- ❌ Manual maintenance required
- ❌ Can be forgotten

**Implementation:**
1. Add `CHANGELOG.md` next to `package.json` in each package folder
2. Follow [Keep a Changelog](https://keepachangelog.com/) format
3. Update before bumping version
4. File gets published with package

**Format:**
```markdown
# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.2] - 2025-01-16

### Fixed
- Fixed null reference in GetComponent method
- Fixed memory leak in coroutine cleanup

### Changed
- Improved performance of Update loop
- Updated dependencies

## [1.0.1] - 2025-01-15

### Added
- New utility method for scene loading
- Support for Unity 2022.3 LTS

### Fixed
- Fixed editor crash on domain reload

## [1.0.0] - 2025-01-10

### Added
- Initial release
- Core functionality
- Basic documentation
```

### Option 2: Semi-Automated from Commit Messages

**Pros:**
- ✅ Less manual work
- ✅ Consistent format
- ✅ Based on actual commits

**Cons:**
- ❌ Requires conventional commit discipline
- ❌ Needs workflow modification
- ❌ May need editing for clarity

**Implementation:**
1. Enforce conventional commits: `feat:`, `fix:`, `chore:`, etc.
2. Add workflow step to generate CHANGELOG.md
3. Use tools like `conventional-changelog` or custom script
4. Commit generated changelog before publishing

**Conventional Commit Format:**
```bash
git commit -m "feat: add scene loading utility method"
git commit -m "fix: resolve null reference in GetComponent"
git commit -m "chore: update dependencies"
git commit -m "docs: improve API documentation"
```

**Workflow addition:**
```yaml
- name: Generate Changelog
  run: |
    cd "$(dirname "$package_json")"

    # Get commits since last version tag
    last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

    if [ -n "$last_tag" ]; then
      commits=$(git log $last_tag..HEAD --pretty=format:"%s" -- .)
    else
      commits=$(git log --pretty=format:"%s" -- .)
    fi

    # Parse conventional commits and generate changelog
    echo "## [$new_version] - $(date +%Y-%m-%d)" >> CHANGELOG.md
    echo "" >> CHANGELOG.md

    # Extract features
    features=$(echo "$commits" | grep "^feat:" | sed 's/^feat: /- /')
    if [ -n "$features" ]; then
      echo "### Added" >> CHANGELOG.md
      echo "$features" >> CHANGELOG.md
      echo "" >> CHANGELOG.md
    fi

    # Extract fixes
    fixes=$(echo "$commits" | grep "^fix:" | sed 's/^fix: /- /')
    if [ -n "$fixes" ]; then
      echo "### Fixed" >> CHANGELOG.md
      echo "$fixes" >> CHANGELOG.md
      echo "" >> CHANGELOG.md
    fi
```

### Option 3: GitHub Releases

**Pros:**
- ✅ Native GitHub feature
- ✅ Visible on repository page
- ✅ Can include assets

**Cons:**
- ❌ Not published with package
- ❌ Requires separate workflow
- ❌ Users must visit GitHub

**Implementation:**
Add to workflow after successful publish:

```yaml
- name: Create GitHub Release
  if: success()
  run: |
    gh release create "$package_name@$new_version" \
      --repo "$repository" \
      --title "$package_name $new_version" \
      --notes "Published to UPM registry

    View on registry: https://upm.the1studio.org/-/web/detail/$package_name

    ### Changes
    - TODO: Add changelog"
```

### Option 4: Registry Web UI Display

**Pros:**
- ✅ Integrated with registry
- ✅ Always available with package
- ✅ No extra files in package

**Cons:**
- ❌ Requires Verdaccio plugin or API
- ❌ More complex implementation
- ❌ Not standard for Unity packages

**Implementation:**
Requires Verdaccio plugin development or API integration.

## Recommendation Matrix

| Scenario | Recommended Approach |
|----------|---------------------|
| **Small team, few packages** | Manual CHANGELOG.md |
| **Large team, many packages** | Semi-automated + manual review |
| **Strict versioning process** | Manual CHANGELOG.md + GitHub Releases |
| **Minimal maintenance** | Semi-automated only |

## Best Practices

### 1. Manual CHANGELOG.md Workflow

**Developer workflow:**
```bash
# 1. Make changes
git add .

# 2. Update CHANGELOG.md
edit UI/Utilities/CHANGELOG.md

# 3. Bump version in package.json
edit UI/Utilities/package.json

# 4. Commit and push
git add UI/Utilities/
git commit -m "feat(ui-utilities): add scene loading helper"
git push origin master

# 5. Auto-publish happens
# Workflow detects package.json change and publishes
```

**CHANGELOG.md location:**
```
TheOneFeature/
├── UI/
│   └── Utilities/
│       ├── package.json
│       ├── CHANGELOG.md          ← Add here
│       ├── README.md
│       └── Runtime/
```

### 2. Keep a Changelog Format

Required sections:
- **Added** - New features
- **Changed** - Changes in existing functionality
- **Deprecated** - Soon-to-be removed features
- **Removed** - Removed features
- **Fixed** - Bug fixes
- **Security** - Security fixes

### 3. Semantic Versioning Alignment

Match changelog sections to semver:
- **MAJOR** (1.0.0 → 2.0.0) - Breaking changes (Removed, Changed)
- **MINOR** (1.0.0 → 1.1.0) - New features (Added)
- **PATCH** (1.0.0 → 1.0.1) - Bug fixes (Fixed, Security)

### 4. Automation Helpers

**Pre-commit hook to remind about changelog:**
```bash
#!/bin/bash
# .git/hooks/pre-commit

changed_packages=$(git diff --cached --name-only | grep package.json)

for pkg in $changed_packages; do
  changelog="${pkg%package.json}CHANGELOG.md"

  if ! git diff --cached --name-only | grep -q "$changelog"; then
    echo "⚠️  Warning: $pkg changed but $changelog not updated"
    echo "Did you update the changelog?"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      exit 1
    fi
  fi
done
```

**VS Code task to open changelog:**
```json
{
  "label": "Open Package Changelog",
  "type": "shell",
  "command": "code ${fileDirname}/CHANGELOG.md",
  "presentation": {
    "reveal": "always"
  }
}
```

## Discord Notification Enhancement (Future)

Currently Discord shows:
```
### 🔧 com.theone.ui.utilities
┣━ Version: 1.0.1 ➜ 1.0.2
┣━ Change Type: 🟢 PATCH
┣━ Registry: https://upm.the1studio.org/-/web/detail/...
┗━ Source: https://github.com/.../tree/master/UI/Utilities
```

**Possible enhancement:**
```
### 🔧 com.theone.ui.utilities
┣━ Version: 1.0.1 ➜ 1.0.2
┣━ Change Type: 🟢 PATCH
┣━ Registry: https://upm.the1studio.org/-/web/detail/...
┣━ Source: https://github.com/.../tree/master/UI/Utilities
┗━ Changes:
   • Fixed null reference in GetComponent
   • Improved performance of Update loop
```

**Implementation:**
Extract last section from CHANGELOG.md and add to Discord notification (limited to 200 chars).

## Migration Plan

### Phase 1: Template Creation
1. Create `CHANGELOG.md` template
2. Add to UPMAutoPublisher docs
3. Document in setup instructions

### Phase 2: Existing Packages
1. Create CHANGELOG.md for all packages in TheOneFeature
2. Add current version as baseline
3. Use "Initial tracked version" for first entry

### Phase 3: Documentation
1. Update developer guidelines
2. Add changelog best practices
3. Create PR template reminder

### Phase 4: Optional Automation
1. Add pre-commit hook template
2. Create VS Code tasks
3. Add changelog extraction to Discord (optional)

## Example Templates

### Template 1: New Package
```markdown
# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-01-16

### Added
- Initial release
```

### Template 2: Existing Package
```markdown
# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.17] - 2025-01-16

### Changed
- Now tracking changes in this file

---

Previous versions were released but not documented in changelog format.
Changelog tracking begins with version 1.0.17.
```

## References

- [Keep a Changelog](https://keepachangelog.com/)
- [Semantic Versioning](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Unity Package Layout](https://docs.unity3d.com/Manual/cus-layout.html)

## Decision

**Recommended for The1Studio:**

1. **Start with Manual CHANGELOG.md** (Phase 1-2)
   - Simple, immediate
   - Add template to docs
   - Create baseline for existing packages

2. **Add Pre-commit Reminder** (Phase 3)
   - Optional but helpful
   - Prevents forgotten changelogs

3. **Consider Automation Later** (Phase 4)
   - After team establishes habit
   - If conventional commits are adopted
   - If volume becomes overwhelming

**Next Steps:**
1. Review this document
2. Create CHANGELOG.md template
3. Add 1-2 example changelogs in TheOneFeature
4. Update setup documentation
5. Roll out to team

---

**Last Updated:** 2025-01-16
