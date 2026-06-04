#!/usr/bin/env bash
set -euo pipefail

# MAIN_BRANCH_URL is used for version checks (always points to latest).
MAIN_BRANCH_URL="https://raw.githubusercontent.com/deckerr95/decky-plugin-manager/main"
VERSION_URL="$MAIN_BRANCH_URL/version"

# REPO_RAW_URL is used to download the script payload for this specific version.
# Changed to the release tag by prepare-release.sh, reverted to main by restore-development-urls.sh.
REPO_RAW_URL="https://raw.githubusercontent.com/deckerr95/decky-plugin-manager/main"

AUTO_YES=0
UPDATE_MODE=0

HAS_WHIPTAIL=0

is_interactive() {
  [[ -t 0 && -t 1 ]]
}

if command -v whiptail >/dev/null 2>&1 && is_interactive; then
  HAS_WHIPTAIL=1
fi

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

ui_info() {
  local message="$1"

  if [[ "$HAS_WHIPTAIL" -eq 1 ]]; then
    whiptail \
      --title "Decky Plugin Manager" \
      --msgbox "$message" \
      12 70
  else
    echo "$message"
  fi
}

ui_error() {
  local message="$1"

  if [[ "$HAS_WHIPTAIL" -eq 1 ]]; then
    whiptail \
      --title "Decky Plugin Manager - Error" \
      --msgbox "$message" \
      12 70
  else
    echo "ERROR: $message" >&2
  fi
}

ui_confirm() {
  local prompt="$1"

  if [[ "$AUTO_YES" -eq 1 ]]; then
    return 0
  fi

  if [[ "$HAS_WHIPTAIL" -eq 1 ]]; then
    whiptail \
      --title "Decky Plugin Manager" \
      --yesno "$prompt" \
      12 70
    return $?
  fi

  read -rp "$prompt" confirm
  [[ "$confirm" =~ ^[Yy]$ ]]
}

# fetch remote version
REMOTE_VERSION="$(curl -fsSL --max-time 5 "$VERSION_URL" | head -n 1 | tr -d ' \n')"
if [[ -z "$REMOTE_VERSION" ]]; then
  ui_error "Failed to fetch remote version."
  exit 1
fi

REINSTALL_CONFIRMED=0

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
  INSTALL_MESSAGE=$(
    cat <<EOF
Installing Decky Plugin Manager

Version: $REMOTE_VERSION
EOF
  )

  ui_info "$INSTALL_MESSAGE"
else
  UPDATE_MESSAGE=$(
    cat <<EOF
Updating Decky Plugin Manager

Current version: $CURRENT_VERSION
New version: $REMOTE_VERSION
EOF
  )

  ui_info "$UPDATE_MESSAGE"

  if [[ -n "$CURRENT_VERSION" && "$CURRENT_VERSION" == "$REMOTE_VERSION" ]]; then
    ui_info "Already up to date."

    if ui_confirm "Reinstall anyway?"; then
      REINSTALL_CONFIRMED=1
    else
      ui_info "Aborted."
      exit 0
    fi
  fi

  # detect downgrade
  if [[ "$(printf '%s\n' "$CURRENT_VERSION" "$REMOTE_VERSION" | sort -V | head -n1)" != "$CURRENT_VERSION" ]]; then
    ui_info "Warning: this will downgrade the installed version."
  fi
fi

if [[ "$REINSTALL_CONFIRMED" -eq 1 ]]; then
  :
else
  if ! ui_confirm "Proceed with installation?"; then
    ui_info "Aborted."
    exit 1
  fi
fi

# download
TMP="$(mktemp)"
if ! curl -fsSL "$REPO_RAW_URL/decky-plugin-manager.sh" -o "$TMP"; then
  ui_error "Failed to download installer payload."
  exit 1
fi

# install
mv "$TMP" "$TARGET"
chmod +x "$TARGET"

# symlink (short alias)
ln -sf "$TARGET" "$SYMLINK"

# ensure PATH hint (no sudo needed for user-local install)
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  ui_info "Note: add to PATH if needed: export PATH=\"$INSTALL_DIR:\$PATH\""
fi

# Main launcher
tmpfile="$(mktemp)"
cat > "$tmpfile" <<EOF
[Desktop Entry]
Name=Decky Plugin Manager (DPM)
Comment=Enable/disable Decky Loader plugins
Exec=konsole -e bash -lc "$SYMLINK"
Terminal=false
Type=Application
Icon=system-run
Categories=Utility;
StartupNotify=false
EOF
mv -f "$tmpfile" "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

# Uninstall launcher
tmpfile="$(mktemp)"
cat > "$tmpfile" <<EOF
[Desktop Entry]
Name=Decky Plugin Manager (Uninstall)
Comment=Remove Decky Plugin Manager
Exec=konsole -e bash -lc "$SYMLINK --uninstall"
Terminal=false
Type=Application
Icon=edit-delete
Categories=Utility;
StartupNotify=false
EOF
mv -f "$tmpfile" "$UNINSTALL_DESKTOP_FILE"
chmod +x "$UNINSTALL_DESKTOP_FILE"


INSTALLED_VERSION="$("$TARGET" --version 2>/dev/null | tr -d ' \n')"

FINAL_MESSAGE=$(
  cat <<EOF
Installed: $TARGET

Installed version: $INSTALLED_VERSION

$(
if [[ "$INSTALLED_VERSION" == "$REMOTE_VERSION" ]]; then
  echo "Verification: OK"
else
  echo "Verification: FAILED (expected $REMOTE_VERSION)"
fi
)

Alias: $SYMLINK

Desktop entries created:
 - $DESKTOP_FILE
 - $UNINSTALL_DESKTOP_FILE
 - (use 'Add to Steam' to run in Gaming Mode)

Run with:
 - $BIN_NAME
 - dpm
 - Decky Plugin Manager (DPM)
EOF
)

if [[ "$HAS_WHIPTAIL" -eq 1 ]]; then
  LINES=$(tput lines 2>/dev/null || echo 40)
  COLS=$(tput cols 2>/dev/null || echo 100)

  H=$((LINES - 6))
  W=$((COLS - 10))

  (( H < 20 )) && H=20
  (( W < 70 )) && W=70

  whiptail \
    --title "Decky Plugin Manager" \
    --scrolltext \
    --msgbox "$FINAL_MESSAGE" \
    "$H" "$W"
else
  ui_info "$FINAL_MESSAGE"
fi

# Refresh KDE app cache to make it pick up new desktop launchers
if command -v kbuildsycoca5 >/dev/null 2>&1; then
  kbuildsycoca5 --noincremental >/dev/null 2>&1 || true
elif command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi

if [[ "$HAS_WHIPTAIL" -eq 1 ]]; then
  exit 0
fi

if [[ "$UPDATE_MODE" -ne 1 && -t 0 ]]; then
  read -rp "Press Enter to exit..."
fi
