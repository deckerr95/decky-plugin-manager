#!/usr/bin/env bash
set -euo pipefail

# REPO_RAW_URL="https://raw.githubusercontent.com/deckerr95/decky-plugin-manager/latest"
# REPO_RAW_URL="https://raw.githubusercontent.com/deckerr95/decky-plugin-manager/main"
REPO_RAW_URL="http://192.168.1.161:8000"
VERSION_URL="$REPO_RAW_URL/version"

AUTO_YES=0
UPDATE_MODE=0

for arg in "$@"; do
  case "$arg" in
    --yes)
      AUTO_YES=1
      ;;
    --update)
      UPDATE_MODE=1
      AUTO_YES=1
      ;;
  esac
done

confirm() {
  local prompt="$1"

  if [[ "$AUTO_YES" -eq 1 ]]; then
    return 0
  fi

  read -rp "$prompt" confirm
  [[ "$confirm" =~ ^[Yy]$ ]]
}

# fetch remote version
REMOTE_VERSION="$(curl -fsSL --max-time 5 "$VERSION_URL" | head -n 1 | tr -d ' \n')"
if [[ -z "$REMOTE_VERSION" ]]; then
  echo "Failed to fetch remote version."
  exit 1
fi

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(eval echo ~$USER_NAME)"
DESKTOP_FILE="$USER_HOME/.local/share/applications/dpm.desktop"
UNINSTALL_DESKTOP_FILE="$USER_HOME/.local/share/applications/dpm-uninstall.desktop"
INSTALL_DIR="$USER_HOME/.local/bin"

BIN_NAME="decky-plugin-manager"
TARGET="$INSTALL_DIR/$BIN_NAME"
SYMLINK="$INSTALL_DIR/dpm"

CURRENT_VERSION=""
if [[ -f "$TARGET" ]]; then
  if CURRENT_VERSION="$("$TARGET" --version 2>/dev/null)"; then
    CURRENT_VERSION="$(echo "$CURRENT_VERSION" | tr -d ' \n')"
  else
    CURRENT_VERSION="unknown"
  fi
fi

mkdir -p "$INSTALL_DIR"

if [[ -z "$CURRENT_VERSION" ]]; then
  echo "Installing Decky Plugin Manager"
  echo "Version: $REMOTE_VERSION"
else
  echo "Updating Decky Plugin Manager"
  echo "Current version: $CURRENT_VERSION"
  echo "New version: $REMOTE_VERSION"

  if [[ -n "$CURRENT_VERSION" && "$CURRENT_VERSION" == "$REMOTE_VERSION" ]]; then
    echo "Already up to date."
    if ! confirm "Reinstall anyway? [y/N]: "; then
      echo "Aborted."
      exit 1
    fi
  fi

  # detect downgrade
  if [[ "$(printf '%s\n' "$CURRENT_VERSION" "$REMOTE_VERSION" | sort -V | head -n1)" != "$CURRENT_VERSION" ]]; then
    echo "Warning: this will downgrade the installed version."
  fi
fi

echo

if ! confirm "Proceed? [y/N]: "; then
  echo "Aborted."
  exit 1
fi

echo

# download
TMP="$(mktemp)"
if ! curl -fsSL "$REPO_RAW_URL/decky-plugin-manager.sh" -o "$TMP"; then
  echo "Failed to download installer payload."
  exit 1
fi

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

INSTALLED_VERSION="$("$TARGET" --version 2>/dev/null | tr -d ' \n')"

echo "Installed: $TARGET"
echo "Installed version: $INSTALLED_VERSION"

if [[ "$INSTALLED_VERSION" == "$REMOTE_VERSION" ]]; then
  echo "Verification: OK"
else
  echo "Verification: FAILED (expected $REMOTE_VERSION)"
fi
echo "Alias: $SYMLINK"
echo
echo "Desktop entries created:"
echo " - $DESKTOP_FILE"
echo " - $UNINSTALL_DESKTOP_FILE"
echo " - (use 'Add to Steam' to run in Gaming Mode)"
echo
echo "Run with: $BIN_NAME or dpm, or using the desktop launcher: Decky Plugin Manager (DPM)"
echo

if [[ -t 0 ]]; then
  read -rp "Press Enter to exit..."
fi
