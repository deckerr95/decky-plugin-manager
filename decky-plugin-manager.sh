#!/bin/bash
set -e

# handle uninstall before anything else
if [[ "${1:-}" == "--uninstall" ]]; then
  TARGET="$(readlink -f "$0")"
  INSTALL_DIR="$(dirname "$TARGET")"
  SYMLINK="$INSTALL_DIR/dpm"

  read -rp "Uninstall decky-plugin-manager? [y/N]: " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || exit 0

  rm -f "$SYMLINK"
  rm -f "$TARGET"

  echo "Uninstalled decky-plugin-manager."
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
