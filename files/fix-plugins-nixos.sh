#!/usr/bin/env bash
# Fix plugin scripts for NixOS compatibility
# Run after: /plugin updates, /reload-plugins, or when seeing "/bin/bash: bad interpreter"

set -e

echo "Fixing plugin shebangs for NixOS..."

# Fix /bin/bash -> /usr/bin/env bash (both cache and marketplaces)
for dir in ~/.claude/plugins/cache ~/.claude/plugins/marketplaces; do
  if [[ -d "$dir" ]]; then
    find "$dir" -name "*.sh" -type f -exec sed -i 's|^#!/bin/bash|#!/usr/bin/env bash|' {} \; 2>/dev/null || true
    # Fix /bin/sh if needed (usually fine, but just in case)
    find "$dir" -name "*.sh" -type f -exec sed -i 's|^#!/bin/sh|#!/usr/bin/env sh|' {} \; 2>/dev/null || true
  fi
done

# Count fixed files
FIXED=$(find ~/.claude/plugins/cache ~/.claude/plugins/marketplaces -name "*.sh" -type f 2>/dev/null | wc -l)
echo "Checked $FIXED shell scripts in plugin directories"
echo "Done!"
