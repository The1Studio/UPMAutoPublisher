# UPM Auto Publisher

Automated Unity Package Manager (UPM) publishing system for The1Studio organization. This system automatically detects package version changes and publishes them to `upm.the1studio.org` registry.

## Overview

This repository contains the GitHub Actions workflow and documentation for automatically publishing Unity packages to The1Studio's private UPM registry whenever package.json versions are updated.

### How It Works

1. **Trigger**: Monitors all registered repositories for commits to master/main branch
2. **Detection**: Identifies changed `package.json` files in the commit
3. **Version Check**: For each changed package:
   - Extracts package name and version from package.json
   - Queries `upm.the1studio.org` to check if version already exists
   - Skips if version is already published
4. **Publishing**: If new version detected:
   - Changes to package directory
   - Runs `npm publish --registry https://upm.the1studio.org/`
   - Handles errors gracefully (continues with other packages if one fails)
5. **Multi-Package Support**: Handles repos with multiple Unity packages

### Key Features

- **Automatic Detection**: No manual triggers needed - just update version in package.json and commit
- **Multi-Package Support**: Handles repos with multiple UPM packages
- **Smart Version Checking**: Only publishes if version doesn't exist on registry
- **Error Resilient**: Continues publishing other packages if one fails
- **Organization-Wide**: Single NPM token shared across all repositories
- **Tag-Free**: No need to manually create git tags (simplified from upm/{version} approach)

## Architecture

### Components

1. **GitHub Actions Workflow** (`.github/workflows/publish-upm.yml`)
   - Triggered on push to master/main
   - Detects package.json changes
   - Publishes to UPM registry

2. **Repository Registry** (`config/repositories.json`)
   - Lists all repositories that should use auto-publishing
   - Tracks package locations within each repo

3. **Setup Scripts** (`docs/setup-instructions.md`)
   - Step-by-step guide for adding workflow to new repos
   - NPM token configuration
   - GitHub organization secret setup

## Quick Start

### For Repository Maintainers

To publish a new package version:

1. Update version in your package.json:
   ```json
   {
     "version": "1.2.11"  // Increment from 1.2.10
   }
   ```

2. Commit and push to master:
   ```bash
   git add Assets/YourPackage/package.json
   git commit -m "Bump version to 1.2.11"
   git push origin master
   ```

3. GitHub Actions automatically publishes to upm.the1studio.org

That's it! No tags, no manual publishing.

### For New Repository Setup

See [Setup Instructions](docs/setup-instructions.md) for adding the workflow to a new repository.

## Configuration

### Repository Registry

Track which repositories use auto-publishing in `config/repositories.json`:

```json
{
  "repositories": [
    {
      "name": "UnityBuildScript",
      "url": "https://github.com/The1Studio/UnityBuildScript",
      "packages": [
        {
          "name": "com.theone.foundation.buildscript",
          "path": "Assets/BuildScripts"
        }
      ]
    },
    {
      "name": "UnityUtilities",
      "url": "https://github.com/The1Studio/UnityUtilities",
      "packages": [
        {
          "name": "com.theone.utilities.core",
          "path": "Assets/Utilities/Core"
        },
        {
          "name": "com.theone.utilities.ui",
          "path": "Assets/Utilities/UI"
        }
      ]
    }
  ]
}
```

### GitHub Secrets Required

- `NPM_TOKEN`: Organization-level secret for npm authentication
  - Used to publish to upm.the1studio.org
  - Set once at organization level, available to all repos

## Tag Naming Convention

For multi-package repositories, we use:
```
upm/{package-name}/{version}
```

Examples:
- `upm/buildscript/1.2.10`
- `upm/utilities-core/2.0.1`
- `upm/utilities-ui/1.5.3`

**Note**: Based on discussion, we're actually NOT creating tags automatically anymore to simplify the workflow. This section is kept for reference.

## Workflow Logic

```bash
# 1. Detect changed package.json files
changed_packages=$(git diff HEAD~1 --name-only | grep package.json)

# 2. For each changed package
for package_json in $changed_packages; do
  # Extract package info
  package_dir=$(dirname "$package_json")
  package_name=$(jq -r '.name' "$package_json")
  new_version=$(jq -r '.version' "$package_json")

  # Check if version exists on registry
  if ! npm view "$package_name@$new_version" --registry https://upm.the1studio.org/ 2>/dev/null; then
    echo "Publishing $package_name@$new_version..."

    # Publish to registry
    cd "$package_dir"
    npm publish --registry https://upm.the1studio.org/

    echo "✅ Published $package_name@$new_version"
  else
    echo "⏭️  Version $new_version already exists for $package_name, skipping"
  fi
done
```

## Error Handling

- **Version Already Exists**: Skip publishing, log message
- **Package Not Found**: Skip (not a UPM package)
- **Publish Fails**: Log error, continue with other packages
- **Auth Fails**: Stop workflow, report error

## Benefits

### Before (Manual Process)
1. Update package.json version
2. Commit changes
3. Create git tag: `git tag upm/1.2.10`
4. Push commit: `git push`
5. Push tag: `git push --tags`
6. CD to package directory
7. Publish: `npm publish --registry https://upm.the1studio.org/`

### After (Automated)
1. Update package.json version
2. Commit and push

**Time saved**: ~5 manual steps eliminated per release

## Troubleshooting

See [Troubleshooting Guide](docs/troubleshooting.md) for common issues and solutions.

## Requirements

- GitHub repository in The1Studio organization
- Unity package with package.json containing:
  - `name`: Package identifier
  - `version`: Semantic version
  - `publishConfig.registry`: Set to `https://upm.the1studio.org/`

## Related Documentation

- [Setup Instructions](docs/setup-instructions.md) - How to add workflow to new repos
- [NPM Token Setup](docs/npm-token-setup.md) - Creating and configuring NPM authentication
- [Workflow Reference](docs/workflow-reference.md) - Detailed workflow documentation
- [Architecture Decisions](docs/architecture-decisions.md) - Design choices and rationale

## Support

For issues or questions:
1. Check [Troubleshooting Guide](docs/troubleshooting.md)
2. Review [GitHub Actions logs](https://github.com/The1Studio/UPMAutoPublisher/actions)
3. Contact DevOps team

## Version History

- **v1.0.0** (2025-01-16): Initial release
  - Auto-detection of package.json changes
  - Organization-level NPM token
  - Multi-package repository support
  - No git tag requirement

## License

MIT License - See LICENSE file for details
