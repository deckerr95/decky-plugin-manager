#!/bin/bash

set -euo pipefail

MAIN_URL="https://raw.githubusercontent.com/deckerr95/decky-plugin-manager/main"

if [[ "$OSTYPE" == "darwin"* ]]; then
  SED="sed -i ''"
else
  SED="sed -i"
fi

echo "=== Restoring development URLs ==="

# Revert REPO_RAW_URL back to main branch in both scripts
$SED "s|^REPO_RAW_URL=.*|REPO_RAW_URL=\"${MAIN_URL}\"|" decky-plugin-manager.sh
echo "  decky-plugin-manager.sh REPO_RAW_URL → main"

$SED "s|^REPO_RAW_URL=.*|REPO_RAW_URL=\"${MAIN_URL}\"|" install.sh
echo "  install.sh REPO_RAW_URL → main"

# Revert desktop launcher to download from main branch
$SED "s|curl -fsSL [^ ]*/install.sh|curl -fsSL ${MAIN_URL}/install.sh|g" install-decky-plugin-manager.desktop
echo "  install-decky-plugin-manager.desktop URL → main"

echo ""
echo "=== Development URLs restored ==="
echo ""
echo "Commit the changes:"
echo "  git add decky-plugin-manager.sh install.sh install-decky-plugin-manager.desktop"
echo "  git commit -m \"Restore development URLs after release\""