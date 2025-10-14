# Automated Testing with BATS

## Overview

This directory is reserved for automated tests using the **BATS** (Bash Automated Testing System) framework.

## Why BATS?

BATS is ideal for testing bash scripts and shell workflows:
- Native bash syntax - easy to write and maintain
- Comprehensive assertions for exit codes, output, files
- Integration testing support for entire workflows
- CI/CD friendly with TAP output format

## Setup BATS

### Installation

```bash
# Ubuntu/Debian
sudo apt-get install bats

# macOS
brew install bats-core

# Manual installation
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

### Verify Installation

```bash
bats --version
# Should output: Bats 1.x.x
```

## Test Structure

```
tests/
├── README.md                    # This file
├── setup_suite.bash             # Global setup for all tests
├── teardown_suite.bash          # Global teardown
├── test_config_validation.bats  # Config/JSON validation tests
├── test_scripts.bats            # Script functionality tests
└── fixtures/                    # Test data and mocks
    ├── valid_config.json
    ├── invalid_config.json
    └── mock_responses/
```

## Example Test File

Create `tests/test_config_validation.bats`:

```bash
#!/usr/bin/env bats

# Load test helpers
load test_helper

@test "validate-config.sh accepts valid repositories.json" {
  run ./scripts/validate-config.sh
  [ "$status" -eq 0 ]
  [[ "$output" =~ "validation passed" ]]
}

@test "validate-config.sh rejects invalid JSON" {
  # Create temporary invalid config
  echo "{ invalid json" > /tmp/test-invalid.json

  run bash -c "cd config && ln -sf /tmp/test-invalid.json repositories.json"
  run ./scripts/validate-config.sh

  [ "$status" -ne 0 ]
  [[ "$output" =~ "validation failed" ]]

  # Cleanup
  rm /tmp/test-invalid.json
}

@test "schema.json validates package structure" {
  # Test with missing required field
  cat > /tmp/test-config.json <<EOF
{
  "repositories": [
    {
      "name": "TestRepo",
      "url": "https://github.com/test/repo"
      // Missing "packages" field
    }
  ]
}
EOF

  run ajv validate -s config/schema.json -d /tmp/test-config.json
  [ "$status" -ne 0 ]

  rm /tmp/test-config.json
}
```

## Recommended Test Coverage

### High Priority Tests

1. **Configuration Validation** (`test_config_validation.bats`)
   - Valid repositories.json passes validation
   - Invalid JSON is rejected
   - Schema validation catches missing fields
   - URL format validation works
   - Package path validation works

2. **Script Functionality** (`test_scripts.bats`)
   - pre-deployment-check.sh catches all critical issues
   - validate-config.sh correctly validates configs
   - audit-repos.sh handles API errors gracefully
   - check-single-repo.sh accepts multiple input formats

3. **Security Tests** (`test_security.bats`)
   - Command injection protection in publish workflow
   - Markdown injection detection in register workflow
   - Token validation in setup-secrets.sh
   - Input sanitization for package names/versions

4. **Integration Tests** (`test_integration.bats`)
   - End-to-end workflow simulation
   - Mock GitHub API responses
   - Test registry connectivity checks
   - Retry logic verification

### Test Helpers

Create `tests/test_helper.bash`:

```bash
# Common setup for all tests
setup() {
  # Create temporary directory for test isolation
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR

  # Save original directory
  ORIG_DIR="$PWD"
  export ORIG_DIR
}

teardown() {
  # Cleanup temporary files
  rm -rf "$TEST_TEMP_DIR"

  # Return to original directory
  cd "$ORIG_DIR"
}

# Helper: Create mock GitHub API response
mock_github_api() {
  local endpoint="$1"
  local response="$2"

  # Create mock script that returns response
  cat > "$TEST_TEMP_DIR/gh-mock" <<EOF
#!/bin/bash
echo '$response'
EOF
  chmod +x "$TEST_TEMP_DIR/gh-mock"

  # Add to PATH
  export PATH="$TEST_TEMP_DIR:$PATH"
}

# Helper: Verify no sensitive data in output
assert_no_secrets() {
  local output="$1"

  # Check for common secret patterns
  [[ ! "$output" =~ ghp_ ]]
  [[ ! "$output" =~ github_pat_ ]]
  [[ ! "$output" =~ npm_[A-Za-z0-9]{36} ]]
}
```

## Running Tests

### Run All Tests

```bash
bats tests/
```

### Run Specific Test File

```bash
bats tests/test_config_validation.bats
```

### Run with Verbose Output

```bash
bats -t tests/
```

### Run in CI/CD (TAP output)

```bash
bats --formatter tap tests/
```

## CI/CD Integration

Add to `.github/workflows/test.yml`:

```yaml
name: Run Tests

on:
  push:
    branches: [master, main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install BATS
        run: |
          sudo apt-get update
          sudo apt-get install -y bats

      - name: Install dependencies
        run: |
          sudo apt-get install -y jq shellcheck yamllint
          npm install -g ajv-cli

      - name: Run tests
        run: bats tests/

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: test-results.tap
```

## Best Practices

1. **Test Isolation**: Each test should be independent
2. **Cleanup**: Always cleanup temporary files in teardown
3. **Descriptive Names**: Test names should clearly describe what they test
4. **Fast Tests**: Keep tests fast - use mocks for external services
5. **Comprehensive Coverage**: Test both success and failure paths
6. **Security Focus**: Explicitly test injection prevention
7. **Real-World Scenarios**: Test with actual repository structures

## Mocking External Services

### Mock GitHub API

```bash
# In test file
setup() {
  # Mock gh CLI
  export GH_MOCK_RESPONSES="$TEST_TEMP_DIR/gh-responses"
  mkdir -p "$GH_MOCK_RESPONSES"

  # Create mock gh script
  cat > "$TEST_TEMP_DIR/gh" <<'EOF'
#!/bin/bash
# Return pre-configured responses based on arguments
if [[ "$*" =~ "pr list" ]]; then
  cat "$GH_MOCK_RESPONSES/pr-list.json"
elif [[ "$*" =~ "repo view" ]]; then
  cat "$GH_MOCK_RESPONSES/repo-view.json"
fi
EOF
  chmod +x "$TEST_TEMP_DIR/gh"
  export PATH="$TEST_TEMP_DIR:$PATH"
}
```

### Mock NPM Registry

```bash
# Mock npm command
setup() {
  cat > "$TEST_TEMP_DIR/npm" <<'EOF'
#!/bin/bash
if [[ "$*" =~ "view" ]]; then
  echo "1.0.0"
elif [[ "$*" =~ "publish" ]]; then
  echo "+ package@1.0.1"
  exit 0
fi
EOF
  chmod +x "$TEST_TEMP_DIR/npm"
  export PATH="$TEST_TEMP_DIR:$PATH"
}
```

## Current Status

**Status**: Framework documented, no tests implemented yet

**Priority**: LOW (L-7) - Recommended for long-term maintainability

**Next Steps**:
1. Install BATS on development machines
2. Create test_helper.bash with common utilities
3. Start with config validation tests (easiest)
4. Add security tests for injection prevention
5. Add integration tests for workflows
6. Enable CI/CD testing in GitHub Actions

## References

- [BATS Core](https://github.com/bats-core/bats-core)
- [BATS Tutorial](https://bats-core.readthedocs.io/en/stable/)
- [Testing Bash with BATS](https://opensource.com/article/19/2/testing-bash-bats)
- [BATS Assertions](https://github.com/bats-core/bats-assert)
- [BATS File](https://github.com/bats-core/bats-file)

---

**Note**: While automated tests are recommended, they are not required for the current security audit compliance. Manual validation via `scripts/pre-deployment-check.sh` provides adequate coverage for production deployment.
