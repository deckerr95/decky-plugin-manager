#!/bin/bash
# Usage: ./make-release.sh <version>
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

VERSION="$1"
TAG="v${VERSION}"
ORIGINAL_DIR="$(pwd)"
RELEASE_WORKTREE_DIR="../decky-release-worktree-${TAG}"

echo "=== Preparing release ${TAG} ==="

# 1. Update version file and decky-plugin-manager.sh in main
echo "${VERSION}" > version
# Using sed -i with '' for cross-platform compatibility (macOS/Linux)
if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' "s|^VERSION=".*"|VERSION="${VERSION}"|" decky-plugin-manager.sh
else
  sed -i "s|^VERSION=".*"|VERSION="${VERSION}"|" decky-plugin-manager.sh
fi
echo "  version file → ${VERSION}"
echo "  decky-plugin-manager.sh VERSION → ${VERSION}"

# 2. Commit version bump to main
git add version decky-plugin-manager.sh
echo "  To commit version bump to main, execute: "
echo "  git commit -m \"Bump version to ${VERSION}\""
read -p "Press Enter to continue..."
echo "  Committed version bump to main."

# 3. Create/Update release branch (never delete)
echo "  Checking for existing 'release' branch..."
if ! git show-ref --verify --quiet refs/heads/release; then
    echo "  'release' branch does not exist. Creating from 'main'..."
    git branch release main
    echo "  'release' branch created."
fi

# Ensure worktree directory is clean before adding
git worktree remove "$RELEASE_WORKTREE_DIR" --force || true
rm -rf "$RELEASE_WORKTREE_DIR"
git worktree prune
git worktree add "$RELEASE_WORKTREE_DIR" release
echo "  Worktree added for 'release' branch at $RELEASE_WORKTREE_DIR."

# Copy main branch contents into the worktree, overwriting existing files
echo "  Copying main branch contents into the worktree (overwriting release branch files)..."
# Use rsync if available, otherwise fallback to cp
if command -v rsync >/dev/null 2>&1; then
    # rsync excludes .git automatically when syncing to a git worktree
    rsync -av --delete --exclude='.kilo' . "$RELEASE_WORKTREE_DIR/"
else
    # Fallback: remove all files from worktree except .git, then copy from main
    find "$RELEASE_WORKTREE_DIR" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
    cp -r . "$RELEASE_WORKTREE_DIR/" 2>/dev/null || true  # ignore .git copy errors
    rm -rf "$RELEASE_WORKTREE_DIR/.kilo" 2>/dev/null || true  # ensure .kilo is removed
fi
echo "  Main branch contents copied to worktree, overwriting release branch files."

# Apply release-specific changes directly to the worktree directory
# 4. Update URLs in release worktree
echo "  Updating URLs in release worktree for ${TAG}..."
# Set the RELEASE_TAG environment variable for the script execution in the worktree
# This will make the REPO_URL in install.sh and decky-plugin-manager.sh use the tag
export RELEASE_TAG="${TAG}"

# For install-decky-plugin-manager.desktop, we still need to update the URL
# because its content directly points to raw.githubusercontent.com.
RELEASE_RAW_URL_FOR_DESKTOP="https://raw.githubusercontent.com/deckerr95/decky-plugin-manager/${TAG}"
if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' "s|curl -fsSL [^ ]*/install.sh|curl -fsSL ${RELEASE_RAW_URL_FOR_DESKTOP}/install.sh|g" "$RELEASE_WORKTREE_DIR/install-decky-plugin-manager.desktop"
else
  sed -i "s|curl -fsSL [^ ]*/install.sh|curl -fsSL ${RELEASE_RAW_URL_FOR_DESKTOP}/install.sh|g" "$RELEASE_WORKTREE_DIR/install-decky-plugin-manager.desktop"
fi
echo "  install-decky-plugin-manager.desktop URL → ${TAG} tag"

# Commit the desktop launcher change to the release branch within the worktree
git -C "$RELEASE_WORKTREE_DIR" add "install-decky-plugin-manager.desktop"
echo "  To commit desktop launcher change to 'release' branch, execute: "
echo "  git -C \"$RELEASE_WORKTREE_DIR\" commit -m \"Update desktop launcher for ${TAG} release\""
read -p "Press Enter to continue..."
echo "  Committed desktop launcher changes to 'release' branch."

# Exit worktree directory before tagging and pushing
cd "$ORIGINAL_DIR" > /dev/null

# 5. Tag and push
echo "  Tagging and pushing changes..."
git tag "${TAG}"
echo "  To push changes, execute: "
echo "  git push origin main \"${TAG}\""
echo "  git push origin release"
read -p "Press Enter to continue..."
echo "  Pushed main, release, and tag to origin."

# 6. Cleanup
echo "  Cleaning up worktree..."
git worktree remove "$RELEASE_WORKTREE_DIR" --force
git worktree prune
rm -rf "$RELEASE_WORKTREE_DIR"
echo "  Worktree cleaned."

echo ""
echo "=== Release ${TAG} prepared! ==="
echo ""
echo "Next steps:"
echo "  1. Create a GitHub release from tag ${TAG}."
echo "  2. GitHub Actions will handle attaching the necessary files (decky-plugin-manager.sh, install.sh, install-decky-plugin-manager.desktop, version) as release assets automatically."
