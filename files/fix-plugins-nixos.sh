#!/usr/bin/env bash
# Fix plugin scripts for NixOS compatibility
# Run after: /plugin updates, /reload-plugins, or when seeing "/bin/bash: bad interpreter"

set -e

echo "Fixing plugin shebangs for NixOS..."

# Fix /bin/bash -> /usr/bin/env bash
find ~/.claude/plugins/cache -name "*.sh" -type f -exec sed -i 's|^#!/bin/bash|#!/usr/bin/env bash|' {} \; 2>/dev/null || true

# Fix /bin/sh if needed (usually fine, but just in case)
find ~/.claude/plugins/cache -name "*.sh" -type f -exec sed -i 's|^#!/bin/sh|#!/usr/bin/env sh|' {} \; 2>/dev/null || true

# Count fixed files
FIXED=$(find ~/.claude/plugins/cache -name "*.sh" -type f | wc -l)
echo "Checked $FIXED shell scripts in plugin cache"
echo "Done!"
