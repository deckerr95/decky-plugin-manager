#!/bin/bash

unset LD_PRELOAD
unset LD_LIBRARY_PATH

VERSION=0.6.0

# MAIN_BRANCH_URL is used for version checks and update downloads (always points to latest).
if [[ -n "${RELEASE_TAG:-}" ]]; then
    REPO_URL="https://raw.githubusercontent.com/deckerr95/decky-plugin-manager/${RELEASE_TAG}"
else
    REPO_URL="https://raw.githubusercontent.com/deckerr95/decky-plugin-manager/main"
fi
VERSION_URL="$REPO_URL/version"

HAS_WHIPTAIL=0

if command -v whiptail >/dev/null 2>&1; then
  HAS_WHIPTAIL=1
fi

menu() {
  local title="$1"
  shift

  if [[ "$HAS_WHIPTAIL" -eq 1 ]]; then
    whiptail \
      --title "$title" \
      --menu "" \
      20 70 10 \
      "$@" \
      3>&1 1>&2 2>&3
  else
    echo "$title" >&2
    echo >&2

    while [[ $# -gt 0 ]]; do
      local key="$1"
      local desc="$2"

      echo "$key) $desc" >&2

      shift 2
    done

    echo >&2
    read -rp "Select option: " choice >&2

    printf '%s\n' "$choice"
  fi
}

msgbox() {
  local text="$1"

  if [[ "$HAS_WHIPTAIL" -eq 1 ]]; then
    whiptail \
      --title "Decky Plugin Manager" \
      --scrolltext \
      --msgbox "$text" \
      20 70
  else
    clear
    echo "$text"
    echo
    read -rp "Press Enter to continue..."
  fi
}

has_plugins() {
  local f

  for f in "$PLUG"/* "$DIS"/*; do
    [[ -e "$f" ]] && return 0
  done

  return 1
}

show_no_plugins() {
  msgbox "No plugins installed."
}

init_paths() {
  USER_NAME="${SUDO_USER:-$USER}"
  BASE="$(eval echo ~${SUDO_USER:-$USER})"
  PLUG="$BASE/homebrew/plugins"
  DIS="$BASE/homebrew.disabled"

  mkdir -p "$PLUG"
  mkdir -p "$DIS"
}

SUDO_PASS=""

ensure_sudo() {
  if sudo -n true 2>/dev/null; then
    return 0
  fi

  SUDO_PASS=$(whiptail --title "Authentication Required" \
    --passwordbox "Root access required to continue:" 10 60 3>&1 1>&2 2>&3)

  if [[ -z "$SUDO_PASS" ]]; then
    return 1
  fi

  echo "$SUDO_PASS" | sudo -S -v >/dev/null 2>&1

  if [[ $? -ne 0 ]]; then
    SUDO_PASS=""
    return 1
  fi

  SUDO_PASS=""
  return 0
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

uninstall_plugin() {
  local path="$1"

  if [[ ! -e "$path" ]]; then
    return 1
  fi

  if [[ "$(stat -c '%U' "$path")" == "root" ]]; then
    if [[ "$HAS_WHIPTAIL" -eq 1 ]]; then
      ensure_sudo || return 1
      sudo rm -rf "$path" || return 1
    else
      echo
      echo "Root privileges required to uninstall plugin..."
      sudo rm -rf "$path" || return 1
      return
    fi
  else
    rm -rf "$path" || return 1
  fi
}

move() {
  local src="$1"
  local dst="$2"

  # Check if destination exists and is a directory
  if [[ -e "$dst" ]]; then
    if [[ ! -d "$dst" ]]; then
      # Destination exists but is not a directory
      if [[ "$HAS_WHIPTAIL" -eq 1 ]]; then
        whiptail --title "Error" --msgbox "Destination exists and is not a directory:\n$dst" 10 60
      else
        echo "Error: Destination exists and is not a directory: $dst" >&2
      fi
      return 1
    fi

    # Destination is a directory, ask for confirmation to remove it
    local confirm
    if [[ "$HAS_WHIPTAIL" -eq 1 ]]; then
      whiptail --title "Confirm replacement" --yesno "The destination directory already exists:\n$dst\n\nDo you want to remove it and replace it with the source?" 12 70
      confirm=$?
      # whiptail returns 0 for Yes, 1 for No
      if [[ $confirm -ne 0 ]]; then
        return 1
      fi
    else
      echo
      echo "The destination directory already exists:"
      echo "$dst"
      echo
      read -rp "Do you want to remove it and replace it with the source? [y/N]: " confirm
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        return 1
      fi
    fi

    # User confirmed, remove the destination directory
    # Determine sudo need based on destination ownership
    local dst_owner
    dst_owner="$(stat -c '%U' "$dst")"
    if [[ "$dst_owner" == "root" ]]; then
      if [[ "$HAS_WHIPTAIL" -eq 1 ]]; then
        ensure_sudo || return 1
        sudo rm -rf "$dst" || return 1
      else
        echo
        echo "Removing existing destination directory (owned by root)..."
        sudo rm -rf "$dst" || return 1
      fi
    else
      rm -rf "$dst" || return 1
    fi
  fi

  if [[ "$(stat -c '%U' "$src")" == "root" ]]; then
    if [[ "$HAS_WHIPTAIL" -eq 1 ]]; then
      ensure_sudo || return 1
      sudo mv "$src" "$dst" || return 1
    else
      echo
      echo "The plugin's directory is owned by root. Please provide root password to continue: "
      sudo mv "$src" "$dst" || return 1
    fi
  else
    mv "$src" "$dst" || return 1
  fi
}

check_for_update() {
  local remote

  remote="$(curl -fsSL --connect-timeout 10 --max-time 5 "$VERSION_URL" 2>/dev/null | head -n 1 | tr -d ' \n')"

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
  TMP="$(mktemp)"
  
  if curl -fsSL "$MAIN_BRANCH_URL/install.sh" -o "$TMP" &&
    env -i HOME="$BASE" USER="$USER_NAME" SUDO_USER="${SUDO_USER:-}" PATH="$PATH" RELEASE_TAG="$RELEASE_TAG" bash "$TMP" --update --yes; then
    echo
    echo "Update completed successfully."
    echo "Please restart Decky Plugin Manager to use the updated version."
  else
    echo
    echo "Update failed."
  fi
  
  rm -f "$TMP"

  echo
  read -rp "Press Enter to continue..."
}

handle_update_check() {
  local text
  local uopt

  [[ "$HAS_WHIPTAIL" -eq 0 ]] && clear

  echo "Checking for updates..."
  echo

  REMOTE_VERSION=""

  if ! check_for_update; then
    msgbox "Failed to fetch latest version."
    return
  fi

  text="Current version: $VERSION
Latest version: $REMOTE_VERSION"

  if [[ "$REMOTE_VERSION" == "$VERSION" ]]; then
    msgbox "$text

You are already up to date."
    return
  fi

  if [[ "$HAS_WHIPTAIL" -eq 1 ]]; then
    uopt=$(whiptail \
      --title "Update Available" \
      --menu "$text

An update is available." \
      20 70 5 \
      "1" "Update now" \
      "2" "Back" \
      3>&1 1>&2 2>&3)

    [[ $? -ne 0 ]] && return
  else
    echo "$text"
    echo
    echo "An update is available."
    echo
    echo "1) Update now"
    echo "2) Back"
    echo

    read -rp "Select option: " uopt
  fi

  case "$uopt" in
    1)
      install_update
      ;;
  esac
}

build_plugin_list() {
  declare -n _options="$1"
  declare -n _map="$2"

  local f name display field
  local IFS
  local -a all_plugins sorted

  all_plugins=()

  # collect enabled
  for f in "$PLUG"/*; do
    [ -e "$f" ] || continue
    [[ -L "$f" ]] && continue  # Skip symlinks to prevent path traversal
    name=$(basename "$f")
    all_plugins+=("${name}"$'\x1f'"$f"$'\x1f'"enabled")
  done

  # collect disabled
  for f in "$DIS"/*; do
    [ -e "$f" ] || continue
    [[ -L "$f" ]] && continue  # Skip symlinks to prevent path traversal
    name=$(basename "$f")
    all_plugins+=("${name}"$'\x1f'"$f"$'\x1f'"disabled")
  done

  # sort alphabetically by plugin name
  sorted=($(printf '%s\n' "${all_plugins[@]}" | sort))

  # rebuild output (whiptail-compatible key/value + CLI fallback)
  for entry in "${sorted[@]}"; do
    IFS=$'\x1f' read -r name path state <<< "$entry"

    if [[ "$HAS_WHIPTAIL" -eq 1 ]]; then
      local status_label
      status_label="$([[ "$state" == "enabled" ]] && echo "Enabled" || echo "Disabled")"

      _options+=("$name" "$status_label")
      _map["$name"]="$path"$'\x1f'"$state"
    else
      display="$name ($([[ "$state" == "enabled" ]] && echo "Enabled" || echo "Disabled"))"
      _options+=("$display")
      _map["$display"]="$path"$'\x1f'"$state"
    fi
  done
}

uninstall_plugin_menu_loop() {
  while true; do
    clear

    declare -A map=()
    declare -a options=()

    build_plugin_list options map

    if ! has_plugins; then
      show_no_plugins
      return
    fi

    if [[ "$HAS_WHIPTAIL" -eq 1 ]]; then
      local choice

      choice=$(whiptail \
        --title "Uninstall Plugins" \
        --menu "Select a plugin to uninstall:" \
        20 70 10 \
        "${options[@]}" \
        3>&1 1>&2 2>&3)

      [[ $? -ne 0 ]] && return

    else
      echo "Uninstall Plugins"
      echo
      echo "Select a plugin to uninstall."
      echo
      echo "Plugins:"
      echo

      options=("Go back" "${options[@]}")

      select choice in "${options[@]}"; do
        [[ -z "$choice" ]] && continue
        break
      done

      [[ "$choice" == "Go back" ]] && return
    fi

    IFS=$'\x1f' read -r path state <<< "${map[$choice]}"
    name=$(basename "$path")

    local confirm=""

    if [[ "$HAS_WHIPTAIL" -eq 1 ]]; then
      whiptail \
        --title "Confirm uninstall" \
        --yesno "Uninstall plugin?\n\n$name\n\n$path" 12 70

      if [[ $? -ne 0 ]]; then
        msgbox "Uninstall cancelled"
        continue
      fi
    else
      clear
      echo "About to uninstall:"
      echo
      echo "- Plugin: $name"
      echo "- Status: $state"
      echo "- Path: $path"
      echo
      read -rp "Type 'yes' to confirm [yes/NO]: " confirm

      if [[ "$confirm" != "yes" ]]; then
        msgbox "Uninstall cancelled"
        continue
      fi
    fi

    if uninstall_plugin "$path"; then
      msgbox "$name uninstalled"
    else
      msgbox "Operation failed: $name not uninstalled"
    fi
  done
}

plugin_menu_loop() {
  while true; do
    declare -A map=()
    declare -a options=()

    build_plugin_list options map

    if ! has_plugins; then
      show_no_plugins
      return
    fi

    if [[ "$HAS_WHIPTAIL" -eq 1 ]]; then
      local choice

      choice=$(whiptail \
        --title "Enable/Disable Plugins" \
        --menu "Select a plugin to toggle its state:" \
        20 70 10 \
        "${options[@]}" \
        3>&1 1>&2 2>&3)

      [[ $? -ne 0 ]] && return

      [[ "$choice" == "Go back" ]] && return

    else
      clear
      echo "Enable/Disable Plugins"
      echo
      echo "Select a plugin to toggle its state."
      echo

      options=("Go back" "${options[@]}")

      select choice in "${options[@]}"; do
        [[ -z "$choice" ]] && continue
        [[ "$choice" == "Go back" ]] && return
        break
      done
    fi

    IFS=$'\x1f' read -r path state <<< "${map[$choice]}"
    name=$(basename "$path")

    if [[ "$state" == "enabled" ]]; then
      if move "$path" "$DIS/$name"; then
        msgbox "$name disabled"
      else
        msgbox "Operation failed: $name not changed"
      fi
    else
      if move "$path" "$PLUG/$name"; then
        msgbox "$name enabled"
      else
        msgbox "Operation failed: $name not changed"
      fi
    fi
  done
}

main_menu() {
  while true; do
    
    [[ "$HAS_WHIPTAIL" -eq 0 ]] && clear

    opt=$(menu \
      "Decky Plugin Manager $VERSION" \
      "1" "Enable/disable plugins" \
      "2" "Uninstall plugins" \
      "3" "Check for update" \
      "4" "Exit"
    )

    [[ $? -ne 0 ]] && exit 0

    case "$opt" in
      1)
        plugin_menu_loop
        ;;
      2)
        uninstall_plugin_menu_loop
        ;;
      3)
        handle_update_check
        ;;
      4)
        exit 0
        ;;
    esac
  done
}

init_paths
main_menu
