#!/bin/bash
set -e

VERSION="0.5.0"

# REPO_RAW_URL="https://raw.githubusercontent.com/deckerr95/decky-plugin-manager/main"
REPO_RAW_URL="http://192.168.1.161:8000"
VERSION_URL="$REPO_RAW_URL/version"

init_paths() {
  USER_NAME="${SUDO_USER:-$USER}"
  BASE="$(eval echo ~${SUDO_USER:-$USER})"
  PLUG="$BASE/homebrew/plugins"
  DIS="$BASE/homebrew.disabled"

  mkdir -p "$PLUG"
  mkdir -p "$DIS"
}

if [[ "${1:-}" == "--version" ]]; then
  echo "$VERSION" | tr -d ' \n'
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

check_for_update() {
  local remote

  remote="$(curl -fsSL --connect-timeout 2 --max-time 5 "$VERSION_URL" 2>/dev/null | head -n 1 | tr -d ' \n')"

  if [[ -z "$remote" ]]; then
    echo "Failed to fetch latest version."
    return 1
  fi
  
  if [[ ! "$remote" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
    echo "Remote version format is invalid."
    return 1
  fi

  REMOTE_VERSION="$remote"
  return 0
}

install_update() {
  echo
  echo "Updating Decky Plugin Manager..."
  echo

  if curl -fsSL "$REPO_RAW_URL/install.sh" | env -i HOME="$BASE" PATH="$PATH" bash; then
    echo
    echo "Update completed successfully."
    echo "Please restart Decky Plugin Manager to use the updated version."
  else
    echo
    echo "Update failed."
  fi

  echo
  read -rp "Press Enter to continue..."
}

handle_update_check() {
  clear
  echo "Checking for updates..."
  echo

  REMOTE_VERSION=""

  if check_for_update; then
    echo "Current version: $VERSION"
    echo "Latest version: $REMOTE_VERSION"
    echo
  else
    echo "Failed to fetch latest version."
    echo
    read -rp "Press Enter to continue..."
    return
  fi

  if [[ "$REMOTE_VERSION" != "$VERSION" ]]; then
    echo "An update is available."
    echo
    echo "1) Update now"
    echo "2) Back"
    echo

    read -rp "Select option: " uopt

    case "$uopt" in
      1)
        install_update
        return
        ;;

      2|"")
        return
        ;;
    esac

  else
    echo "You are already up to date."
    echo
    read -rp "Press Enter to continue..."
    return
  fi
}

build_plugin_list() {
  declare -n _options="$1"
  declare -n _map="$2"

  _options=("Exit" "Check for updates")

  local f name display

  for f in "$PLUG"/*; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    display="$name (Enabled)"
    _options+=("$display")
    _map["$display"]="$f|enabled"
  done

  for f in "$DIS"/*; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    display="$name (Disabled)"
    _options+=("$display")
    _map["$display"]="$f|disabled"
  done
}

init_paths

while true; do
  clear

  TITLE="Decky Plugin Manager $VERSION"
  echo -e "$TITLE"
  
  echo "Select a plugin to enable/disable."
  echo "Changes require restarting Steam/system to take effect."
  echo

  declare -A map=()
  declare -a options=()

  build_plugin_list options map

  echo "Plugins:"
  select opt in "${options[@]}"; do
    if [[ "$opt" == "Check for updates" ]]; then
      handle_update_check
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

    echo
    read -rp "Press Enter to continue..."
    break
  done
done
