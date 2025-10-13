# CLAUDE.md - UPM Auto Publisher

This file provides guidance to Claude Code when working with this repository.

## Project Overview

**UPM Auto Publisher** is an automation system for The1Studio organization that automatically publishes Unity Package Manager (UPM) packages to `upm.the1studio.org` when package versions are updated.

**Purpose:** Simplify the package publishing workflow from 7 manual steps to just 2 (update version + push).

**Key Components:**
- GitHub Actions workflow template (`.github/workflows/publish-upm.yml`)
- Repository registry (`config/repositories.json`)
- Comprehensive documentation (`docs/`)

## Repository Structure

```
UPMAutoPublisher/
├── .github/workflows/
│   └── publish-upm.yml           # Main workflow template
├── config/
│   ├── repositories.json         # Registry of repos using auto-publishing
│   └── schema.json              # JSON schema for validation
├── docs/
│   ├── setup-instructions.md    # How to add workflow to repos
│   ├── npm-token-setup.md       # NPM authentication setup
│   ├── troubleshooting.md       # Common issues and solutions
│   └── architecture-decisions.md # Design rationale
├── README.md                     # Main documentation
└── CLAUDE.md                     # This file

```

## How It Works

### Workflow Trigger
```yaml
on:
  push:
    branches: [master, main]
    paths: ['**/package.json']
```

### Publishing Logic
1. Detect changed `package.json` files via `git diff`
2. Extract package name and version from each file
3. Check if version exists on `upm.the1studio.org`
4. If new version: publish to registry
5. Continue with other packages if one fails

### Key Design Decisions
- **Trigger:** On commit (not on tags)
- **Authentication:** Organization-level NPM token
- **Discovery:** Auto-detect packages (no config needed)
- **Error Handling:** Continue on failure (multi-package support)
- **Tags:** No automatic git tag creation

## Common Tasks

### Adding a New Repository to the Registry

1. Edit `config/repositories.json`:
```json
{
  "name": "NewRepository",
  "url": "https://github.com/The1Studio/NewRepository",
  "status": "active",
  "packages": [
    {
      "name": "com.theone.newpackage",
      "path": "Assets/NewPackage",
      "latestVersion": "1.0.0"
    }
  ]
}
```

2. Validate JSON:
```bash
jq . config/repositories.json
```

### Updating Documentation

All documentation is in `docs/`:
- **Setup:** `setup-instructions.md`
- **NPM Token:** `npm-token-setup.md`
- **Troubleshooting:** `troubleshooting.md`
- **Architecture:** `architecture-decisions.md`

When updating docs:
- Keep examples current
- Update "lastUpdated" date in repository.json
- Cross-reference related docs
- Test commands/code samples

### Modifying the Workflow

Template is in `.github/workflows/publish-upm.yml`

**Important sections:**
- **Triggers:** Lines 3-9 (when workflow runs)
- **Node setup:** Lines 17-20 (Node.js version)
- **Detection:** Lines 35-39 (finding changed files)
- **Publishing:** Lines 92-100 (npm publish command)

**Testing changes:**
1. Create test repo or use existing
2. Copy modified workflow to test repo
3. Make package.json change and push
4. Verify workflow behavior in Actions tab
5. Check package published to registry

## Environment Setup

### Prerequisites
- Node.js 18+ (for testing locally)
- `jq` for JSON manipulation
- `gh` CLI (optional, for GitHub operations)
- Access to The1Studio organization
- NPM authentication to `upm.the1studio.org`

### Local Testing

Test workflow logic without running in GitHub Actions:

```bash
# Simulate change detection
changed_files=$(git diff --name-only HEAD~1 HEAD | grep 'package\.json$')

# Process each package
for package_json in $changed_files; do
  package_name=$(jq -r '.name' "$package_json")
  new_version=$(jq -r '.version' "$package_json")

  echo "Would publish: $package_name@$new_version"

  # Test if version exists
  npm view "$package_name@$new_version" --registry https://upm.the1studio.org/

  # Dry-run publish
  cd "$(dirname "$package_json")"
  npm publish --dry-run --registry https://upm.the1studio.org/
done
```

## NPM Token Management

### Current Token Location
- Stored as: `NPM_TOKEN` GitHub organization secret
- Scope: The1Studio organization
- Registry: `upm.the1studio.org`

### Checking Token
```bash
# Verify token works
npm whoami --registry https://upm.the1studio.org/
# Should output: admin

# List tokens
npm token list --registry https://upm.the1studio.org/
```

### Rotating Token
See `docs/npm-token-setup.md` for complete instructions.

## Troubleshooting Quick Reference

### Workflow Not Running
- Check branch is master/main
- Verify package.json actually changed
- Check Actions are enabled in repo settings

### Publish Failed
- Verify NPM_TOKEN secret exists
- Check package.json has `publishConfig.registry`
- Ensure version doesn't already exist

### Multi-Package Issues
- Each must have `publishConfig.registry`
- Check workflow logs for each package
- Verify all packages have unique names

**Full troubleshooting:** See `docs/troubleshooting.md`

## Architecture Principles

1. **Developer Experience First:** Minimize steps to publish
2. **Fail Safe:** Can re-run workflows safely
3. **Organization-Wide:** Consistent across all repos
4. **Minimal Configuration:** Auto-discovery preferred
5. **Observable:** Clear logging and error messages

See `docs/architecture-decisions.md` for detailed rationale.

## Important Files

### Workflow Template
**Location:** `.github/workflows/publish-upm.yml`
**Purpose:** Copy this to repositories that need auto-publishing
**Critical:** Keep Node.js version updated, validate YAML syntax

### Repository Registry
**Location:** `config/repositories.json`
**Purpose:** Track which repos use auto-publishing
**Maintenance:** Update when repos added/removed

### Documentation
**Location:** `docs/*.md`
**Purpose:** Comprehensive guides for setup and troubleshooting
**Maintenance:** Keep examples current, test commands

## Development Workflow

### Making Changes

1. **Create Branch:**
   ```bash
   git checkout -b feature/your-change
   ```

2. **Make Changes:**
   - Update relevant files
   - Test locally if possible
   - Update documentation if needed

3. **Validate:**
   ```bash
   # Validate JSON files
   jq . config/repositories.json

   # Validate YAML
   yamllint .github/workflows/publish-upm.yml
   ```

4. **Commit:**
   ```bash
   git add .
   git commit -m "Description of change"
   ```

5. **Push & PR:**
   ```bash
   git push origin feature/your-change
   # Create PR on GitHub
   ```

### Testing in Real Repository

To test workflow changes:

1. Choose a test repository with UPM package
2. Copy modified workflow to test repo
3. Create test version bump
4. Push and monitor Actions tab
5. Verify package published correctly
6. Check logs for errors/warnings

## Security Considerations

### NPM Token
- Stored as organization secret
- Has write permissions to registry
- Should be rotated annually
- If compromised: revoke immediately

### Workflow Permissions
- Uses `secrets.NPM_TOKEN`
- No write access to repository needed (no tag creation)
- Minimal permissions principle

### Package Validation
- Only publishes if `publishConfig.registry` matches
- Checks version doesn't exist first
- Validates package.json structure

## Communication

### When to Update Registry
Update `config/repositories.json` when:
- New repository adds auto-publishing
- Repository removes auto-publishing
- Package added/removed from repo
- Major version milestone reached

### Documentation Updates
Update docs when:
- Workflow behavior changes
- New troubleshooting scenario discovered
- Security requirements change
- New best practice identified

## References

- **Main Docs:** `README.md`
- **Quick Registration:** `docs/quick-registration.md` 🆕 **Automated repo setup (2 min)**
- **Setup Guide:** `docs/setup-instructions.md` (Manual process)
- **Token Setup:** `docs/npm-token-setup.md`
- **Troubleshooting:** `docs/troubleshooting.md`
- **Architecture:** `docs/architecture-decisions.md`
- **Self-Hosted Runners:** `docs/self-hosted-runners.md`
- **Docker Setup:** `.docker/README.md`

## Project Context

### Origin
Created 2025-01-16 to automate UPM package publishing for The1Studio organization.

### Current Status
- Version 1.0.0
- Active development
- UnityBuildScript is first registered repository

### Future Plans
- Roll out to all The1Studio UPM packages
- Add notifications (Slack/Discord)
- Implement changelog generation
- Add metrics and analytics

## For Future Claude Sessions

When starting a new session on this project:

1. **Read README.md first** - Understand overall system
2. **Check config/repositories.json** - See current registered repos
3. **Review recent commits** - Understand recent changes
4. **Check open issues** - Known problems or planned work
5. **Read architecture-decisions.md** - Understand why things work this way

### Common Session Types

**Adding new repository:**
- Edit config/repositories.json
- Verify package.json has correct registry
- Copy workflow to new repo
- Test with version bump

**Troubleshooting workflow:**
- Check docs/troubleshooting.md first
- Review GitHub Actions logs
- Test locally with commands from this file
- Update troubleshooting doc if new issue

**Updating documentation:**
- Locate relevant doc in docs/
- Update content
- Test code examples
- Update cross-references
- Update lastUpdated dates

## Version History

- **v1.0.0** (2025-01-16): Initial release
  - GitHub Actions workflow
  - Auto-detection and publishing
  - Multi-package support
  - Comprehensive documentation

---

**Remember:** This system is designed to be simple, safe, and automatic. Keep that philosophy when making changes.
