#!/bin/bash
set -e

VERSION="0.5.0"

# REPO_RAW_URL="https://raw.githubusercontent.com/deckerr95/decky-plugin-manager/main"
REPO_RAW_URL="http://192.168.1.118:8000"
VERSION_URL="$REPO_RAW_URL/version"

UPDATE_AVAILABLE=0
REMOTE_VERSION=""
UPDATE_CHECK_DONE=0
TMP_VERSION_FILE="$HOME/.cache/dpm/version"

mkdir -p "$(dirname "$TMP_VERSION_FILE")"
if [[ -f "$TMP_VERSION_FILE" ]]; then
  rm -f "$TMP_VERSION_FILE"
fi

GREEN="\e[32m"
RESET="\e[0m"

if [[ "${1:-}" == "--version" ]]; then
  echo "$VERSION"
  exit 0
fi

if [[ "${1:-}" == "--uninstall" ]]; then
  TARGET="$(readlink -f "$0")"
  INSTALL_DIR="$(dirname "$(readlink -f "$0")")"
  SYMLINK="$INSTALL_DIR/dpm"
  USER_HOME="$(eval echo ~${SUDO_USER:-$USER})"
  DESKTOP_FILE="$USER_HOME/.local/share/applications/dpm.desktop"
  UNINSTALL_DESKTOP_FILE="$USER_HOME/.local/share/applications/dpm-uninstall.desktop"

  echo "Uninstalling decky-plugin-manager..."
  echo "Target binary: $TARGET"
  echo "Symlink: $SYMLINK"
  echo

  read -rp "Proceed? [y/N]: " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || exit 0

  if [[ -L "$SYMLINK" || -e "$SYMLINK" ]]; then
    rm -f "$SYMLINK"
    echo "Removed: $SYMLINK"
  else
    echo "Skipped (not found): $SYMLINK"
  fi

  if [[ -f "$TARGET" ]]; then
    rm -f "$TARGET"
    echo "Removed: $TARGET"
  else
    echo "Skipped (not found): $TARGET"
  fi
  
  if [[ -f "$DESKTOP_FILE" ]]; then
    rm -f "$DESKTOP_FILE"
    echo "Removed: $DESKTOP_FILE"
  else
    echo "Skipped (not found): $DESKTOP_FILE"
  fi
  
  if [[ -f "$UNINSTALL_DESKTOP_FILE" ]]; then
    rm -f "$UNINSTALL_DESKTOP_FILE"
    echo "Removed: $UNINSTALL_DESKTOP_FILE"
  else
    echo "Skipped (not found): $UNINSTALL_DESKTOP_FILE"
  fi

  echo
  echo "Uninstall complete."
  exit 0
fi

(
  curl -fsSL \
    --connect-timeout 2 \
    --max-time 5 \
    "$VERSION_URL" -o "$TMP_VERSION_FILE" \
    >/dev/null 2>&1 || true
) </dev/null &
disown

move() {
  if [[ "$(stat -c '%U' "$1")" == "root" ]]; then
    if ! sudo -n true 2>/dev/null; then
      echo
      echo "The plugin's directory is owned by root. Please provide root password to continue: "
    fi
    sudo mv "$1" "$2"
  else
    mv "$1" "$2"
  fi
}

USER_NAME="${SUDO_USER:-$USER}"
BASE="$(eval echo ~${SUDO_USER:-$USER})"
PLUG="$BASE/homebrew/plugins"
DIS="$BASE/homebrew.disabled"

mkdir -p "$PLUG"
mkdir -p "$DIS"

while true; do
  clear
  
  if [[ -f "$TMP_VERSION_FILE" && $UPDATE_CHECK_DONE -eq 0 ]]; then
    REMOTE_VERSION="$(tr -d ' \n' < "$TMP_VERSION_FILE")"

    if [[ -n "$REMOTE_VERSION" ]]; then
      if [[ "$(printf '%s\n' "$VERSION" "$REMOTE_VERSION" | sort -V | tail -n1)" != "$VERSION" ]]; then
        UPDATE_AVAILABLE=1
      fi
    fi

    UPDATE_CHECK_DONE=1
  fi

  TITLE="Decky Plugin Manager $VERSION"
  if [[ $UPDATE_AVAILABLE -eq 1 && -n "$REMOTE_VERSION" ]]; then
    TITLE="$TITLE - ${GREEN}New Update: $REMOTE_VERSION${RESET}"
  fi
  echo -e "$TITLE"
  
  echo "Select a plugin to enable/disable."
  echo "Changes require restarting Steam/system to take effect."
  echo

  declare -A map=()
  options=("Exit")
  [[ $UPDATE_AVAILABLE -eq 1 ]] && options+=("Update to latest")

  for f in "$PLUG"/*; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    display="$name (Enabled)"
    options+=("$display")
    map["$display"]="$f|enabled"
  done

  for f in "$DIS"/*; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    display="$name (Disabled)"
    options+=("$display")
    map["$display"]="$f|disabled"
  done

  echo "Plugins:"
  select opt in "${options[@]}"; do
    if [[ "$opt" == "Update to latest" ]]; then
      echo "Updating..."
      if curl -fsSL "$REPO_RAW_URL/install.sh" | env HOME="$BASE" bash; then
        echo "Update complete. Restarting..."
        sleep 1
        exec "$0" "$@"
      else
        echo "Update failed."
        sleep 3
      fi
      break
    fi
    [ "$opt" = "Exit" ] && exit 0
    [ -z "$opt" ] && break

    IFS='|' read -r path state <<< "${map[$opt]}"
    name=$(basename "$path")

    if [ "$state" = "enabled" ]; then
      move "$path" "$DIS/$name" && echo "Disabled $name"
    else
      move "$path" "$PLUG/$name" && echo "Enabled $name"
    fi

    break
  done

  sleep 3
done
