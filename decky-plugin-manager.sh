#!/bin/bash
set -e

if [[ "${1:-}" == "--uninstall" ]]; then
  TARGET="$(readlink -f "$0")"
  INSTALL_DIR="$(dirname "$TARGET")"
  SYMLINK="$INSTALL_DIR/dpm"

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

  echo
  echo "Uninstall complete."
  exit 0
fi

if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

BASE="$(eval echo ~${SUDO_USER:-$USER})/homebrew"
PLUG="$BASE/plugins"
DIS="$BASE/disabled"
mkdir -p "$DIS"

while true; do
  clear

  echo "Decky Plugin Manager"
  echo "Select a plugin to enable/disable."
  echo "Changes require restarting Steam/system to take effect."
  echo

  declare -A map=()
  options=("Exit")

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
    [ "$opt" = "Exit" ] && exit 0
    [ -z "$opt" ] && break

    IFS='|' read -r path state <<< "${map[$opt]}"
    name=$(basename "$path")

    if [ "$state" = "enabled" ]; then
      mv "$path" "$DIS/$name" && echo "Disabled $name"
    else
      mv "$path" "$PLUG/$name" && echo "Enabled $name"
    fi

    break
  done

  sleep 3
done
