#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
BIN_NAME="decky-plugin-manager"
TARGET="$INSTALL_DIR/$BIN_NAME"
SYMLINK="$INSTALL_DIR/dpm"
CONFIG_DIR="$HOME/.config/decky-plugin-manager"

PURGE=0
[[ "${1:-}" == "--purge" ]] && PURGE=1

removed=0

# pre-check
if [[ ! -e "$TARGET" && ! -L "$SYMLINK" ]]; then
  echo "decky-plugin-manager is not installed."
  exit 0
fi

# remove symlink
if [[ -L "$SYMLINK" || -e "$SYMLINK" ]]; then
  rm -f "$SYMLINK"
  echo "Removed symlink: $SYMLINK"
  removed=1
fi

# remove binary
if [[ -f "$TARGET" ]]; then
  rm -f "$TARGET"
  echo "Removed binary: $TARGET"
  removed=1
fi

# # optional config cleanup
# if [[ $PURGE -eq 1 && -d "$CONFIG_DIR" ]]; then
#   rm -rf "$CONFIG_DIR"
#   echo "Removed config: $CONFIG_DIR"
# fi

if [[ $removed -eq 1 ]]; then
  echo "Uninstalled decky-plugin-manager."
else
  echo "Nothing to remove."
fi