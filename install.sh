#!/usr/bin/env bash
set -euo pipefail

# REPO_RAW_URL="https://raw.githubusercontent.com/deckerr95/decky-plugin-manager/latest"
REPO_RAW_URL="http://192.168.1.118:8000"
INSTALL_DIR="$HOME/.local/bin"
BIN_NAME="decky-plugin-manager"
TARGET="$INSTALL_DIR/$BIN_NAME"
SYMLINK="$INSTALL_DIR/dpm"

DESKTOP_FILE="$HOME/.local/share/applications/dpm.desktop"
UNINSTALL_DESKTOP_FILE="$HOME/.local/share/applications/dpm-uninstall.desktop"

mkdir -p "$INSTALL_DIR"

# download
TMP="$(mktemp)"
curl -fsSL "$REPO_RAW_URL/decky-plugin-manager.sh" -o "$TMP"

# install
mv "$TMP" "$TARGET"
chmod +x "$TARGET"

# symlink (short alias)
ln -sf "$TARGET" "$SYMLINK"

# ensure PATH hint (no sudo needed for user-local install)
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  echo "Note: add to PATH if needed: export PATH=\"$INSTALL_DIR:\$PATH\""
fi

# Main launcher
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=Decky Plugin Manager (DPM)
Comment=Enable/disable Decky Loader plugins
Exec=xdg-terminal-exec bash -c "$SYMLINK"
Terminal=true
Type=Application
Icon=system-run
Categories=Utility;
StartupNotify=false
EOF
chmod +x "$DESKTOP_FILE"

# Uninstall launcher
cat > "$UNINSTALL_DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=Decky Plugin Manager (Uninstall)
Comment=Remove Decky Plugin Manager
Exec=xdg-terminal-exec bash -c "$SYMLINK --uninstall"
Terminal=true
Type=Application
Icon=edit-delete
Categories=Utility;
StartupNotify=false
EOF
chmod +x "$UNINSTALL_DESKTOP_FILE"

echo "Installed: $TARGET"
echo "Alias: $SYMLINK"
echo "Desktop entries created:"
echo " - $DESKTOP_FILE"
echo " - $UNINSTALL_DESKTOP_FILE"
echo " - (use 'Add to Steam' to run in Gaming Mode)"
echo "Run with: $BIN_NAME or dpm"

if [[ -t 0 ]]; then
  read -rp "Press Enter to exit..."
fi
