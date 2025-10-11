# Troubleshooting Guide

Common issues and solutions for UPM auto-publishing system.

## Workflow Issues

### Workflow Not Triggering

**Symptoms:**
- Pushed commit with package.json changes
- No workflow run appears in Actions tab

**Possible Causes & Solutions:**

1. **Wrong branch:**
   ```bash
   # Check current branch
   git branch

   # Workflow only triggers on master/main
   # If on different branch:
   git checkout master
   git merge your-branch
   git push
   ```

2. **Actions disabled:**
   - Go to repository Settings → Actions → General
   - Ensure "Allow all actions and reusable workflows" is selected
   - Check if workflow file exists: `.github/workflows/publish-upm.yml`

3. **Path filter didn't match:**
   ```yaml
   # Workflow triggers on:
   paths:
     - '**/package.json'

   # Verify package.json was in the commit:
   git show --name-only HEAD | grep package.json
   ```

4. **Workflow file has syntax error:**
   ```bash
   # Validate YAML syntax
   yamllint .github/workflows/publish-upm.yml

   # Or use online validator
   # Copy workflow content to https://www.yamllint.com/
   ```

### Workflow Runs But Doesn't Publish

**Symptoms:**
- Workflow completes successfully
- Package not published to registry

**Check These:**

1. **Version already exists:**
   ```bash
   npm view com.theone.yourpackage@1.2.3 --registry https://upm.the1studio.org/
   # If it returns data, version exists
   ```

2. **Missing publishConfig:**
   ```json
   // package.json must have:
   {
     "publishConfig": {
       "registry": "https://upm.the1studio.org/"
     }
   }
   ```

3. **Check workflow logs:**
   - Go to Actions → Click the workflow run
   - Look for "⏭️ Skipped" messages
   - Check why package was skipped

4. **Package validation failed:**
   ```bash
   # Validate package.json
   cd Assets/YourPackage
   npm publish --dry-run --registry https://upm.the1studio.org/
   ```

## Authentication Issues

### 401 Unauthorized Error

**Symptoms:**
```
npm ERR! code E401
npm ERR! 401 Unauthorized - PUT https://upm.the1studio.org/...
```

**Solutions:**

1. **Verify organization secret exists:**
   ```bash
   gh secret list --org The1Studio | grep NPM_TOKEN
   ```

2. **Check secret accessibility:**
   - GitHub → Organization settings → Secrets
   - Verify `NPM_TOKEN` repository access includes your repo

3. **Test token locally:**
   ```bash
   # Get token from GitHub admin
   export NODE_AUTH_TOKEN="npm_xxxxx..."
   npm whoami --registry https://upm.the1studio.org/
   ```

4. **Regenerate token:**
   - See [NPM Token Setup](npm-token-setup.md)
   - Create new token
   - Update GitHub organization secret

### Token Not Found

**Symptoms:**
```
npm ERR! need auth This command requires you to be logged in.
```

**Solutions:**

1. **Check workflow uses correct secret name:**
   ```yaml
   env:
     NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}  # Correct
     # NOT: ${{ secrets.npm_token }}
   ```

2. **Verify secret scope:**
   - Organization secret vs repository secret
   - Check repository has access to organization secret

## Package Issues

### Package Not Found After Publishing

**Symptoms:**
- Workflow says "Successfully published"
- `npm view` doesn't find the package

**Solutions:**

1. **Wait a moment:**
   ```bash
   # Registry may need a few seconds to index
   sleep 10
   npm view com.theone.yourpackage --registry https://upm.the1studio.org/
   ```

2. **Check exact package name:**
   ```bash
   # Verify package name in package.json matches
   jq '.name' Assets/YourPackage/package.json

   # Try viewing with exact name
   npm view "$(jq -r '.name' Assets/YourPackage/package.json)" --registry https://upm.the1studio.org/
   ```

3. **Check registry URL:**
   ```bash
   # Ensure using correct registry
   npm config get registry
   # Should output: https://upm.the1studio.org/ (when configured)
   ```

### Invalid Package Structure

**Symptoms:**
```
npm ERR! Invalid package.json
npm ERR! Missing required field: name
```

**Solutions:**

1. **Validate package.json:**
   ```bash
   cd Assets/YourPackage
   npm pkg fix
   ```

2. **Required fields:**
   ```json
   {
     "name": "com.theone.yourpackage",
     "version": "1.0.0",
     "displayName": "Your Package",
     "description": "Package description",
     "unity": "2022.3"
   }
   ```

3. **Check for JSON syntax errors:**
   ```bash
   jq . Assets/YourPackage/package.json
   # Will show error if invalid JSON
   ```

## Multi-Package Issues

### Only One Package Published

**Symptoms:**
- Changed multiple package.json files
- Only one package published

**Check:**

1. **View workflow logs:**
   - Look for each package in logs
   - Check for skip/error messages

2. **Verify all have publishConfig:**
   ```bash
   # Check all package.json files
   find . -name "package.json" -exec sh -c '
     echo "Checking: $1"
     jq ".publishConfig.registry" "$1"
   ' _ {} \;
   ```

3. **Check version existence:**
   ```bash
   # For each package
   npm view com.theone.package1@version --registry https://upm.the1studio.org/
   npm view com.theone.package2@version --registry https://upm.the1studio.org/
   ```

### Packages Interfere With Each Other

**Symptoms:**
- Publishing one package affects another
- Unexpected behavior in multi-package repo

**Solutions:**

1. **Ensure package.json are in separate directories:**
   ```
   ✅ Good:
   Assets/PackageA/package.json
   Assets/PackageB/package.json

   ❌ Bad:
   Assets/package.json (parent)
   Assets/PackageA/package.json (child)
   ```

2. **Check assembly definitions don't conflict**

3. **Verify each package has unique name:**
   ```bash
   find . -name "package.json" -exec jq -r '.name' {} \;
   # Should show unique names
   ```

## Git and Version Control Issues

### Changes Not Detected

**Symptoms:**
- Updated package.json
- Workflow says no changes

**Solutions:**

1. **Verify file was committed:**
   ```bash
   git show HEAD:Assets/YourPackage/package.json | jq '.version'
   ```

2. **Check diff detection:**
   ```bash
   git diff HEAD~1 HEAD --name-only | grep package.json
   ```

3. **Ensure push completed:**
   ```bash
   git log origin/master..master
   # Should be empty if push succeeded
   ```

### Version Conflicts

**Symptoms:**
- Version published doesn't match expectation
- Old version still showing

**Solutions:**

1. **Check what was actually published:**
   ```bash
   npm view com.theone.yourpackage dist-tags --registry https://upm.the1studio.org/
   ```

2. **Verify committed version:**
   ```bash
   git show HEAD:Assets/YourPackage/package.json | jq '.version'
   ```

3. **Clear npm cache:**
   ```bash
   npm cache clean --force
   npm view com.theone.yourpackage versions --registry https://upm.the1studio.org/
   ```

## Performance Issues

### Workflow Takes Too Long

**Symptoms:**
- Workflow runs for several minutes
- Timeout errors

**Solutions:**

1. **Check number of package.json files:**
   ```bash
   find . -name "package.json" | wc -l
   # Large number may slow down detection
   ```

2. **Optimize workflow:**
   - Ensure fetch-depth: 2 (not higher)
   - Check if jq installation is needed every time

3. **Network issues:**
   - Check registry availability: https://upm.the1studio.org/
   - Try publishing manually to test connection

## Debugging Workflow

### Enable Debug Logging

1. **Repository secrets:**
   - Add `ACTIONS_STEP_DEBUG` = `true`
   - Add `ACTIONS_RUNNER_DEBUG` = `true`

2. **Re-run workflow:**
   - Go to failed workflow run
   - Click "Re-run jobs"
   - Check detailed logs

### Manual Testing

Test workflow logic locally:

```bash
# 1. Detect changes
changed_files=$(git diff --name-only HEAD~1 HEAD | grep 'package\.json$')
echo "$changed_files"

# 2. For each package
for package_json in $changed_files; do
  package_dir=$(dirname "$package_json")
  package_name=$(jq -r '.name' "$package_json")
  new_version=$(jq -r '.version' "$package_json")

  echo "Package: $package_name"
  echo "Version: $new_version"
  echo "Directory: $package_dir"

  # 3. Check if exists
  npm view "$package_name@$new_version" --registry https://upm.the1studio.org/

  # 4. Test publish (dry-run)
  cd "$package_dir"
  npm publish --dry-run --registry https://upm.the1studio.org/
  cd -
done
```

## Common Error Messages

### "npm ERR! 404 Not Found"

**Meaning:** Package never published before (first publish)

**Action:** This is expected for new packages. Workflow will publish it.

### "npm WARN npm npm does not support Node.js"

**Meaning:** Node.js version mismatch

**Action:** Check workflow uses Node.js 18:
```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '18'
```

### "fatal: ambiguous argument 'HEAD~1'"

**Meaning:** Not enough commit history

**Action:** Workflow uses `fetch-depth: 2`. For first commit in repo, this is expected.

## Getting Help

If issue persists:

1. **Collect information:**
   - Workflow run URL
   - Package.json content
   - Error messages from logs
   - Steps to reproduce

2. **Check documentation:**
   - [Setup Instructions](setup-instructions.md)
   - [NPM Token Setup](npm-token-setup.md)
   - [Workflow Reference](workflow-reference.md)

3. **Contact support:**
   - Create issue in UPMAutoPublisher repository
   - Include collected information
   - Tag relevant team members

## Prevention

### Pre-commit Checklist

Before pushing version bump:

- [ ] Version number follows semver
- [ ] Version doesn't already exist on registry
- [ ] package.json has valid JSON
- [ ] publishConfig.registry is correct
- [ ] Tested package locally
- [ ] Changelog updated (if applicable)

### Workflow Health Check

Periodic maintenance:

- [ ] NPM token hasn't expired
- [ ] All repos in registry are up to date
- [ ] No persistent errors in workflow runs
- [ ] Team members know how to use system
- [ ] Documentation is current
