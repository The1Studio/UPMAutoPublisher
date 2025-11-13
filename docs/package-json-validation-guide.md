# Unity Package Manager (UPM) Package.json Validation Guide

**Version:** 1.0.0
**Last Updated:** 2025-11-13
**Purpose:** Comprehensive validation rules and best practices for Unity Package Manager package.json files

---

## 📋 Table of Contents

1. [Required Fields](#required-fields)
2. [Optional But Recommended Fields](#optional-but-recommended-fields)
3. [Field Format Specifications](#field-format-specifications)
4. [Dependencies](#dependencies)
5. [Common Issues and Fixes](#common-issues-and-fixes)
6. [Best Practices](#best-practices)
7. [Validation Severity Levels](#validation-severity-levels)

---

## Required Fields

These fields MUST be present in every package.json file. Missing any of these is a **CRITICAL** issue.

### 1. `name` (string)
**Format:** `com.company.package-name`
- Must start with reverse domain notation (com/org)
- Must be lowercase
- Use hyphens for word separation (not underscores or spaces)
- No special characters except dots and hyphens

**Valid Examples:**
```json
"name": "com.theone.uitemplat"
"name": "com.unity.textmeshpro"
"name": "jp.hadashikick.vcontainer"
```

**Invalid Examples:**
```json
"name": "MyPackage"                    // ❌ Missing reverse domain
"name": "com.theone.UI_Template"       // ❌ Contains underscore
"name": "com.TheOne.UITemplate"        // ❌ Not lowercase
"name": "com.theone.my package"        // ❌ Contains space
```

### 2. `version` (string)
**Format:** Semantic versioning (semver)
- Must follow `MAJOR.MINOR.PATCH` format
- Each component must be a non-negative integer
- No leading zeros allowed
- May include prerelease tags: `-alpha`, `-beta`, `-rc.1`
- May include build metadata: `+20130313144700`

**Valid Examples:**
```json
"version": "1.0.0"
"version": "2.3.15"
"version": "1.0.0-alpha.1"
"version": "1.2.3-beta+exp.sha.5114f85"
```

**Invalid Examples:**
```json
"version": "1.0"                       // ❌ Missing patch version
"version": "01.02.03"                  // ❌ Leading zeros
"version": "v1.0.0"                    // ❌ Contains 'v' prefix
"version": "1.0.0.0"                   // ❌ Too many components
"version": "latest"                    // ❌ Not a valid semver
```

### 3. `displayName` (string)
**Format:** Human-readable package name
- Can contain spaces and capital letters
- Should be concise but descriptive
- Typically 2-6 words
- No emoji or special Unicode characters

**Valid Examples:**
```json
"displayName": "UI Template"
"displayName": "The One Feature System"
"displayName": "Build Script Utilities"
```

**Invalid Examples:**
```json
"displayName": "ui template"           // ⚠️ Should use proper capitalization
"displayName": "This is a very long package name that describes everything about the package in great detail"  // ❌ Too verbose
"displayName": "UI 🎨 Template"        // ❌ Contains emoji
```

### 4. `description` (string)
**Format:** Brief description of package functionality
- Should be 1-3 sentences
- Explain what the package does and its main purpose
- Avoid marketing language
- Maximum 280 characters recommended

**Valid Examples:**
```json
"description": "Provides common UI patterns and components for Unity games."
"description": "A collection of build automation scripts for Unity projects. Supports multiple platforms and CI/CD integration."
```

**Invalid Examples:**
```json
"description": "Package"               // ❌ Too vague
"description": ""                      // ❌ Empty string
"description": "This is the most amazing, revolutionary, game-changing package that will transform your entire Unity development workflow and make you a 10x developer overnight by providing the best features ever created in the history of game development..."  // ❌ Too long and marketing-heavy
```

### 5. `unity` (string)
**Format:** Minimum Unity version required
- Must be in format `YYYY.STREAM` or `YYYY.STREAM.PATCH`
- YYYY = year (e.g., 2020, 2021, 2022)
- STREAM = release stream (1, 2, 3, 4)
- PATCH = optional patch version

**Valid Examples:**
```json
"unity": "2021.3"
"unity": "2022.3"
"unity": "2020.3.48f1"
```

**Invalid Examples:**
```json
"unity": "2021"                        // ❌ Missing stream version
"unity": "5.6.0"                       // ❌ Old format (pre-2017)
"unity": "latest"                      // ❌ Not a valid version
```

---

## Optional But Recommended Fields

These fields should be present for better package quality and discoverability.

### 1. `license` (string)
**Recommended values:**
- `"MIT"`
- `"Apache-2.0"`
- `"BSD-3-Clause"`
- `"Proprietary"` (for internal packages)

**Example:**
```json
"license": "MIT"
```

### 2. `author` (object or string)
**Format (object):**
```json
"author": {
  "name": "The1Studio",
  "email": "dev@the1studio.org",
  "url": "https://the1studio.org"
}
```

**Format (string):**
```json
"author": "The1Studio <dev@the1studio.org>"
```

### 3. `keywords` (array of strings)
**Purpose:** Help users find your package
**Format:**
- Array of 3-7 relevant keywords
- Lowercase preferred
- No duplicate keywords

**Example:**
```json
"keywords": [
  "ui",
  "template",
  "framework",
  "game",
  "utility"
]
```

### 4. `homepage` (string)
**Format:** Valid URL to package documentation or repository

**Example:**
```json
"homepage": "https://github.com/The1Studio/UITemplate"
```

### 5. `repository` (object)
**Format:**
```json
"repository": {
  "type": "git",
  "url": "https://github.com/The1Studio/UITemplate.git"
}
```

---

## Field Format Specifications

### Dependencies Format

**Field:** `dependencies` (object)
**Purpose:** List runtime dependencies

**Format Rules:**
- Keys: Package names (follow same format as `name` field)
- Values: Version constraints

**Valid version constraints:**
```json
"dependencies": {
  "com.unity.textmeshpro": "3.0.6",          // ✅ Exact version
  "jp.hadashikick.vcontainer": "1.17.0",     // ✅ Exact version
  "com.theone.core": "^1.2.0",               // ✅ Caret (compatible)
  "com.theone.utils": "~2.1.0"               // ✅ Tilde (patch updates)
}
```

**Invalid examples:**
```json
"dependencies": {
  "com.unity.textmeshpro": "*",              // ❌ Wildcard (use exact version)
  "com.theone.core": "latest",               // ❌ 'latest' tag (use exact version)
  "com.theone.utils": ""                     // ❌ Empty version string
}
```

**CRITICAL: JSON Syntax:**
- Every dependency entry MUST end with a comma, except the last one
- Missing comma is a CRITICAL syntax error

**Example of missing comma (CRITICAL ERROR):**
```json
"dependencies": {
  "jp.hadashikick.vcontainer": "1.17.0"      // ❌ MISSING COMMA
  "com.unity.textmeshpro": "1.0.0"
}
```

**Correct format:**
```json
"dependencies": {
  "jp.hadashikick.vcontainer": "1.17.0",     // ✅ Has comma
  "com.unity.textmeshpro": "1.0.0"           // ✅ Last entry, no comma
}
```

### DocumentationUrl Format

**Field:** `documentationUrl` (string)
**Format:** Valid HTTPS URL

**Example:**
```json
"documentationUrl": "https://docs.the1studio.org/uitemplat"
```

### ChangelogUrl Format

**Field:** `changelogUrl` (string)
**Format:** Valid HTTPS URL to CHANGELOG.md or releases page

**Example:**
```json
"changelogUrl": "https://github.com/The1Studio/UITemplate/blob/master/CHANGELOG.md"
```

### LicensesUrl Format

**Field:** `licensesUrl` (string)
**Format:** Valid HTTPS URL to LICENSE file

**Example:**
```json
"licensesUrl": "https://github.com/The1Studio/UITemplate/blob/master/LICENSE.md"
```

---

## Common Issues and Fixes

### Issue 1: Missing Comma in Dependencies
**Severity:** CRITICAL

**Problem:**
```json
"dependencies": {
  "jp.hadashikick.vcontainer": "1.17.0"
  "com.unity.textmeshpro": "1.0.0"
}
```

**Error:** `jq: parse error: Expected separator between values`

**Fix:**
```json
"dependencies": {
  "jp.hadashikick.vcontainer": "1.17.0",
  "com.unity.textmeshpro": "1.0.0"
}
```

### Issue 2: Trailing Comma in JSON
**Severity:** CRITICAL

**Problem:**
```json
"dependencies": {
  "jp.hadashikick.vcontainer": "1.17.0",
  "com.unity.textmeshpro": "1.0.0",
}
```

**Fix:**
```json
"dependencies": {
  "jp.hadashikick.vcontainer": "1.17.0",
  "com.unity.textmeshpro": "1.0.0"
}
```

### Issue 3: Invalid Package Name Format
**Severity:** CRITICAL

**Problem:**
```json
"name": "MyAwesomePackage"
```

**Fix:**
```json
"name": "com.company.my-awesome-package"
```

### Issue 4: Invalid Semantic Version
**Severity:** CRITICAL

**Problem:**
```json
"version": "1.0"
```

**Fix:**
```json
"version": "1.0.0"
```

### Issue 5: Wildcard Dependencies
**Severity:** WARNING

**Problem:**
```json
"dependencies": {
  "com.theone.core": "*"
}
```

**Reason:** Wildcard versions can cause unpredictable builds

**Fix:**
```json
"dependencies": {
  "com.theone.core": "1.2.0"
}
```

### Issue 6: Missing Required Fields
**Severity:** CRITICAL

**Problem:**
```json
{
  "name": "com.theone.mypackage",
  "version": "1.0.0"
}
```

**Missing:** `displayName`, `description`, `unity`

**Fix:**
```json
{
  "name": "com.theone.mypackage",
  "version": "1.0.0",
  "displayName": "My Package",
  "description": "A useful package for Unity development.",
  "unity": "2021.3"
}
```

### Issue 7: Duplicate JSON Keys
**Severity:** CRITICAL

**Problem:**
```json
{
  "name": "com.theone.test",
  "version": "1.0.0",
  "version": "1.0.1"
}
```

**Fix:** Keep only the correct version
```json
{
  "name": "com.theone.test",
  "version": "1.0.1"
}
```

---

## Best Practices

### 1. Dependency Management
- ✅ Use exact versions for dependencies (e.g., `"1.17.0"`)
- ✅ Pin major versions to prevent breaking changes
- ✅ Document why specific versions are required
- ❌ Avoid wildcards (`"*"`) or `"latest"`
- ❌ Avoid version ranges unless necessary

### 2. Version Numbering
- ✅ Follow semantic versioning strictly
- ✅ Increment MAJOR for breaking changes
- ✅ Increment MINOR for new features (backward compatible)
- ✅ Increment PATCH for bug fixes
- ❌ Don't skip versions
- ❌ Don't reuse version numbers

### 3. Documentation
- ✅ Provide clear, concise descriptions
- ✅ Include links to documentation
- ✅ Maintain a CHANGELOG.md
- ✅ Document breaking changes clearly
- ❌ Don't use marketing language
- ❌ Don't leave descriptions vague

### 4. Package Naming
- ✅ Use reverse domain notation
- ✅ Use descriptive but concise names
- ✅ Use hyphens for word separation
- ✅ Keep it lowercase
- ❌ Don't use spaces or underscores
- ❌ Don't use special characters
- ❌ Don't use generic names like "utils" or "core" alone

### 5. Unity Version
- ✅ Specify the minimum required Unity version
- ✅ Test package with specified Unity version
- ✅ Update Unity version when using newer features
- ❌ Don't specify unrealistically old versions
- ❌ Don't use "latest" or version ranges

---

## Validation Severity Levels

### CRITICAL Issues (Must Fix Immediately)
These issues will prevent package from functioning or being published:

1. **JSON Syntax Errors**
   - Missing commas
   - Trailing commas
   - Unclosed brackets/braces
   - Invalid escape sequences

2. **Missing Required Fields**
   - `name`
   - `version`
   - `displayName`
   - `description`
   - `unity`

3. **Invalid Field Formats**
   - Invalid package name format
   - Invalid semantic version
   - Duplicate JSON keys

4. **Dependency Issues**
   - Invalid dependency package names
   - Invalid dependency version formats
   - Empty dependency versions

### WARNING Issues (Should Fix Soon)
These issues don't prevent publishing but reduce package quality:

1. **Missing Recommended Fields**
   - `license`
   - `author`
   - `keywords`
   - `repository`

2. **Dependency Best Practices**
   - Wildcard dependencies (`"*"`)
   - Version tag dependencies (`"latest"`)
   - Very old dependency versions

3. **Documentation**
   - Missing `documentationUrl`
   - Missing `changelogUrl`
   - Very brief or vague descriptions

4. **Package Metadata**
   - No keywords (reduces discoverability)
   - No author information
   - No license specified

### INFO Issues (Nice to Have)
These are suggestions for improvement:

1. **Enhanced Metadata**
   - Add `homepage` URL
   - Add more descriptive keywords
   - Add contributor information

2. **Documentation Links**
   - Add `licensesUrl`
   - Add badges or shields
   - Link to issue tracker

---

## Validation Rules Summary

Use this checklist when validating package.json files:

### JSON Structure
- [ ] Valid JSON syntax (no missing/trailing commas)
- [ ] All strings properly quoted
- [ ] All brackets/braces properly closed
- [ ] No duplicate keys

### Required Fields Present
- [ ] `name` field exists and valid format
- [ ] `version` field exists and valid semver
- [ ] `displayName` field exists
- [ ] `description` field exists and not empty
- [ ] `unity` field exists and valid format

### Field Format Validation
- [ ] Package name follows `com.company.package` format
- [ ] Version follows semantic versioning (X.Y.Z)
- [ ] Unity version in correct format (YYYY.STREAM)
- [ ] All URLs are valid HTTPS URLs
- [ ] All dependencies have valid package names
- [ ] All dependency versions are valid

### Best Practices
- [ ] No wildcard dependencies
- [ ] License field present
- [ ] Author information present
- [ ] Keywords array present
- [ ] Description is concise and clear
- [ ] Documentation URLs provided

---

## Example: Perfect Package.json

```json
{
  "name": "com.theone.uitemplat",
  "version": "1.2.0",
  "displayName": "UI Template",
  "description": "A comprehensive UI framework for Unity games with built-in localization, data binding, and screen management.",
  "unity": "2021.3",
  "license": "MIT",
  "author": {
    "name": "The1Studio",
    "email": "dev@the1studio.org",
    "url": "https://the1studio.org"
  },
  "keywords": [
    "ui",
    "framework",
    "localization",
    "data-binding",
    "screens"
  ],
  "homepage": "https://github.com/The1Studio/UITemplate",
  "repository": {
    "type": "git",
    "url": "https://github.com/The1Studio/UITemplate.git"
  },
  "documentationUrl": "https://docs.the1studio.org/uitemplat",
  "changelogUrl": "https://github.com/The1Studio/UITemplate/blob/master/CHANGELOG.md",
  "licensesUrl": "https://github.com/The1Studio/UITemplate/blob/master/LICENSE.md",
  "dependencies": {
    "com.unity.textmeshpro": "3.0.6",
    "jp.hadashikick.vcontainer": "1.17.0",
    "com.theone.extensions": "1.0.0"
  }
}
```

---

## Validation Response Format

When validating a package.json file, return results in this JSON format:

```json
{
  "valid": false,
  "issues": [
    {
      "severity": "critical",
      "type": "syntax_error",
      "field": "dependencies",
      "message": "Missing comma after 'jp.hadashikick.vcontainer'",
      "line": 23,
      "suggestion": "Add comma: \"jp.hadashikick.vcontainer\": \"1.17.0\","
    },
    {
      "severity": "warning",
      "type": "missing_recommended",
      "field": "license",
      "message": "Missing recommended field 'license'",
      "suggestion": "Add: \"license\": \"MIT\""
    }
  ],
  "fixedContent": "{ ... the corrected JSON content ... }",
  "summary": "Found 1 critical and 1 warning issue. JSON syntax error requires immediate fix."
}
```

### Response Field Definitions:

- **valid** (boolean): Overall validation status
- **issues** (array): List of all detected issues
  - **severity** (string): `"critical"`, `"warning"`, or `"info"`
  - **type** (string): Issue category (e.g., `"syntax_error"`, `"missing_required"`, `"invalid_format"`)
  - **field** (string): Which field has the issue
  - **message** (string): Human-readable description
  - **line** (number, optional): Line number where issue occurs
  - **suggestion** (string): How to fix the issue
- **fixedContent** (string): The corrected package.json content (if auto-fixable)
- **summary** (string): Brief summary of validation results

---

**End of Validation Guide**

This guide should be used as the authoritative reference for all package.json validation operations. When in doubt, refer to the examples and rules defined here.
