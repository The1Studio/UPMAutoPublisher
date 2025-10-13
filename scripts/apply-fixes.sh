#!/usr/bin/env bash
# apply-fixes.sh
# Applies all critical and major security fixes to bash scripts

set -euo pipefail

echo "🔧 Applying security fixes to bash scripts..."
echo ""

# Fix 1: Update shebangs to use env
echo "1. Updating shebangs to use /usr/bin/env bash..."
for script in scripts/*.sh; do
  if [ "$script" = "scripts/apply-fixes.sh" ]; then
    continue
  fi

  if head -n 1 "$script" | grep -q "^#!/bin/bash"; then
    sed -i '1s|#!/bin/bash|#!/usr/bin/env bash|' "$script"
    echo "   ✅ Fixed: $script"
  fi
done
echo ""

# Fix 2: Update set -e to set -euo pipefail
echo "2. Updating error handling (set -e → set -euo pipefail)..."
for script in scripts/*.sh; do
  if [ "$script" = "scripts/apply-fixes.sh" ]; then
    continue
  fi

  if grep -q "^set -e$" "$script"; then
    sed -i 's/^set -e$/set -euo pipefail/' "$script"
    echo "   ✅ Fixed: $script"
  fi
done
echo ""

echo "✅ All fixes applied!"
echo ""
echo "Next steps:"
echo "1. Review the changes: git diff scripts/"
echo "2. Test the scripts"
echo "3. Commit the changes"
