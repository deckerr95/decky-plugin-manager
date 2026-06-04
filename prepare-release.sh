#!/bin/bash

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

VERSION="$1"
TAG="v${VERSION}"
RELEASE_DIR="release-${TAG}"
RELEASE_RAW="https://raw.githubusercontent.com/deckerr95/decky-plugin-manager/${TAG}"

echo "=== Preparing release ${TAG} ==="

# 1. Update version file
echo "${VERSION}" > version
echo "  version file → ${VERSION}"

# 2. Update VERSION variable in decky-plugin-manager.sh (but NOT REPO_RAW_URL or MAIN_BRANCH_URL)
if [[ "$OSTYPE" == "darwin"* ]]; then
  SED="sed -i ''"
else
  SED="sed -i"
fi

$SED "s|^VERSION=\".*\"|VERSION=\"${VERSION}\"|" decky-plugin-manager.sh
echo "  decky-plugin-manager.sh VERSION → ${VERSION}"

# 3. Switch REPO_RAW_URL in both scripts to point to the release tag
$SED "s|^REPO_RAW_URL=.*|REPO_RAW_URL=\"${RELEASE_RAW}\"|" decky-plugin-manager.sh
echo "  decky-plugin-manager.sh REPO_RAW_URL → ${TAG} tag"

$SED "s|^REPO_RAW_URL=.*|REPO_RAW_URL=\"${RELEASE_RAW}\"|" install.sh
echo "  install.sh REPO_RAW_URL → ${TAG} tag"

# 4. Update desktop launcher to download install.sh from the release tag
$SED "s|curl -fsSL [^ ]*/install.sh|curl -fsSL ${RELEASE_RAW}/install.sh|g" install-decky-plugin-manager.desktop
echo "  install-decky-plugin-manager.desktop URL → ${TAG} tag"

# 5. Create release directory and copy files
mkdir -p "${RELEASE_DIR}"
cp version decky-plugin-manager.sh install.sh install-decky-plugin-manager.desktop "${RELEASE_DIR}/"
echo "  Release files copied to ${RELEASE_DIR}/"

echo ""
echo "=== Release ${TAG} prepared ==="
echo ""
echo "Next steps:"
echo "  1. Verify files in ${RELEASE_DIR}/"
echo "  2. git add version decky-plugin-manager.sh install.sh install-decky-plugin-manager.desktop"
echo "  3. git commit -m \"Prepare ${TAG} release\""
echo "  4. git tag ${TAG}"
echo "  5. git push origin main && git push origin ${TAG}"
echo "  6. Create GitHub release from tag ${TAG}"
echo "  7. Upload files from ${RELEASE_DIR}/ as release assets"
echo "  8. ./restore-development-urls.sh"
echo "  9. git add . && git commit -m \"Restore development URLs\""