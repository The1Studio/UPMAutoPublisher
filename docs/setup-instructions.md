# Setup Instructions

Complete guide for adding UPM auto-publishing to your repository.

## Prerequisites

- Repository must be in The1Studio GitHub organization
- Must have a Unity package with `package.json`
- Organization NPM token must be configured (see [NPM Token Setup](npm-token-setup.md))
- **Note**: `publishConfig.registry` in package.json is **optional** - the workflow handles registry configuration automatically

## Step-by-Step Setup

### 1. Verify Package Configuration

Ensure your `package.json` has the required Unity package fields:

```json
{
  "name": "com.theone.yourpackage",
  "version": "1.0.0",
  "displayName": "Your Package Name",
  "description": "Package description",
  "unity": "2022.3"
}
```

**Registry Configuration**: The workflow automatically publishes to the configured registry using the `--registry` flag. You do **NOT** need to add `publishConfig.registry` to your package.json.

**How it works:**
- Workflow uses `UPM_REGISTRY` organization variable (default: `https://upm.the1studio.org/`)
- Publishing command: `npm publish --registry "$UPM_REGISTRY"`
- This approach allows centralized registry management without modifying each package.json

**Optional**: If you prefer to include `publishConfig.registry` in your package.json, that's fine too - but the workflow's `--registry` flag takes precedence.

**Location**: The package.json can be anywhere in your repo (e.g., `Assets/YourPackage/package.json`)

### 2. Copy Workflow File

Copy the workflow file to your repository:

```bash
# In your repository root
mkdir -p .github/workflows

# Copy the workflow file
cp /path/to/UPMAutoPublisher/.github/workflows/publish-upm.yml .github/workflows/
```

Or create `.github/workflows/publish-upm.yml` manually with the content from the template.

### 3. Verify GitHub Organization Secret

The workflow uses `secrets.NPM_TOKEN` which should already be configured at organization level.

**To verify:**
1. Go to https://github.com/organizations/The1Studio/settings/secrets/actions
2. Check that `NPM_TOKEN` exists in "Organization secrets"

**If not configured**, see [NPM Token Setup](npm-token-setup.md)

### 4. Register Repository

Add your repository to the registry:

1. Edit `config/repositories.json` in the UPMAutoPublisher repo
2. Add your repository entry:

```json
{
  "repositories": [
    {
      "name": "YourRepositoryName",
      "url": "https://github.com/The1Studio/YourRepositoryName",
      "packages": [
        {
          "name": "com.theone.yourpackage",
          "path": "Assets/YourPackage"
        }
      ]
    }
  ]
}
```

For **multi-package repositories**, add multiple package entries:

```json
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
```

### 5. Test the Workflow

1. Update version in your package.json:
   ```json
   {
     "version": "1.0.1"  // Increment version
   }
   ```

2. Commit and push:
   ```bash
   git add Assets/YourPackage/package.json
   git commit -m "Test auto-publish: bump version to 1.0.1"
   git push origin master
   ```

3. Check GitHub Actions:
   - Go to your repository's Actions tab
   - Look for "Publish to UPM Registry" workflow
   - Verify it runs successfully

4. Verify on registry:
   ```bash
   npm view com.theone.yourpackage@1.0.1 --registry https://upm.the1studio.org/
   ```

## Workflow Behavior

### What Triggers Publishing

- ✅ Commit to `master` or `main` branch
- ✅ Changes to any `package.json` file
- ✅ Version in package.json doesn't exist on registry
- ✅ Package has valid `name` and `version` fields

### What Skips Publishing

- ⏭️ Version already exists on registry
- ⏭️ Missing `name` or `version` in package.json
- ⏭️ Package.json is not a valid Unity package (missing required fields)

### Error Handling

- ❌ If one package fails, workflow continues with others
- ❌ Workflow reports failure at end if any packages failed
- ✅ Detailed logs show what happened to each package

## Multi-Package Repository Setup

For repositories with multiple UPM packages:

1. Each package must have its own `package.json`
2. Update all package versions independently
3. Workflow automatically handles all changed packages
4. Registry configuration is centralized in the workflow (no per-package setup needed)

**Example structure:**
```
YourRepo/
├── Assets/
│   ├── PackageA/
│   │   └── package.json (v1.0.0)
│   └── PackageB/
│       └── package.json (v2.0.0)
└── .github/
    └── workflows/
        └── publish-upm.yml
```

**Publishing both:**
```bash
# Update both versions
sed -i 's/"version": "1.0.0"/"version": "1.0.1"/' Assets/PackageA/package.json
sed -i 's/"version": "2.0.0"/"version": "2.0.1"/' Assets/PackageB/package.json

# Commit and push
git add Assets/*/package.json
git commit -m "Bump versions for PackageA and PackageB"
git push

# Both packages automatically published!
```

## Troubleshooting

### Workflow Not Triggering

**Problem**: Pushed commit but workflow didn't run

**Solutions**:
- Check that you pushed to `master` or `main` branch
- Verify `package.json` file was actually changed in the commit
- Check repository Actions settings (Actions may be disabled)

### Publishing Failed

**Problem**: Workflow ran but package wasn't published

**Solutions**:
1. Check workflow logs in Actions tab
2. Verify NPM_TOKEN secret is set correctly
3. Check if version already exists: `npm view package@version --registry https://upm.the1studio.org/`
4. Verify package.json has required fields (name, version)

### Multiple Packages Not Publishing

**Problem**: Changed multiple package.json files but only one published

**Solutions**:
- Check workflow logs for each package
- Verify each package.json has required fields (name, version)
- Check if some versions already exist on registry

### Authentication Errors

**Problem**: `npm publish` fails with authentication error

**Solutions**:
1. Verify organization secret `NPM_TOKEN` exists
2. Check token hasn't expired: `npm whoami --registry https://upm.the1studio.org/`
3. Regenerate token if needed (see [NPM Token Setup](npm-token-setup.md))

## Best Practices

### Version Management

1. **Follow Semantic Versioning**: `MAJOR.MINOR.PATCH`
   - MAJOR: Breaking changes
   - MINOR: New features (backward compatible)
   - PATCH: Bug fixes

2. **Update Changelog**: Document changes in package CHANGELOG.md or package.json `_upm.changelog`

3. **Test Before Releasing**: Test package locally before bumping version

### Commit Messages

Use clear commit messages when bumping versions:

```bash
# Good
git commit -m "1.2.5: Fix addressable compression configuration"
git commit -m "Bump version to 2.0.0 - Breaking: Removed deprecated API"

# Avoid
git commit -m "update version"
git commit -m "changes"
```

### Multi-Package Coordination

When updating multiple packages in same repo:

1. **Independent versions**: Each package has its own version number
2. **Batch updates**: Can update all at once or separately
3. **Document dependencies**: Note if packages depend on each other

## Next Steps

After setup:

1. ✅ Verify first publish works correctly
2. ✅ Add repository to `config/repositories.json`
3. ✅ Document package-specific release process
4. ✅ Share with team members

## Additional Resources

- [NPM Token Setup](npm-token-setup.md)
- [Workflow Reference](workflow-reference.md)
- [Troubleshooting Guide](troubleshooting.md)
- [Architecture Decisions](architecture-decisions.md)
