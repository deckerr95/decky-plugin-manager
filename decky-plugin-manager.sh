#!/bin/bash
set -e

unset LD_PRELOAD
unset LD_LIBRARY_PATH

VERSION="0.6.0"

# REPO_RAW_URL="https://raw.githubusercontent.com/deckerr95/decky-plugin-manager/main"
REPO_RAW_URL="http://192.168.1.161:8000"
VERSION_URL="$REPO_RAW_URL/version"

# UI backend detection
if command -v whiptail >/dev/null 2>&1; then
  UI_MODE="whiptail"
else
  UI_MODE="cli"
fi

ui_menu() {
  if [[ "$UI_MODE" == "whiptail" ]]; then
    whiptail --title "$1" \
      --menu "$2" 15 60 "$3" \
      "${@:4}" \
      3>&1 1>&2 2>&3
  else
    shift 3
    echo "$1"
    shift

    local items=("$@")
    local i=1

    local labels=()
    local descriptions=()

    for ((j=0; j<${#items[@]}; j+=2)); do
      labels+=("${items[j]}")
      descriptions+=("${items[j+1]}")
    done

    local i=1
    for ((j=0; j<${#labels[@]}; j++)); do
      echo "$i) ${labels[j]} - ${descriptions[j]}"
      ((i++))
    done

    read -rp "Select option: " opt

    # convert numeric selection safely
    if [[ "$opt" =~ ^[0-9]+$ ]]; then
      opt="${labels[$((opt-1))]}"
    fi

    echo "$opt"
  fi
}

init_paths() {
  USER_NAME="${SUDO_USER:-$USER}"
  BASE="$(eval echo ~${SUDO_USER:-$USER})"
  PLUG="$BASE/homebrew/plugins"
  DIS="$BASE/homebrew.disabled"

  mkdir -p "$PLUG"
  mkdir -p "$DIS"
}

ui_confirm() {
  local title="$1"
  local text="$2"

  if [[ "$UI_MODE" == "whiptail" ]]; then
    whiptail --title "$title" --yesno "$text" 10 60 \
      3>&1 1>&2 2>&3
    return $?
  else
    echo
    echo "$text [y/N]"
    read -r ans
    [[ "$ans" == "y" || "$ans" == "yes" ]]
  fi
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
    if ! sudo -n true 2>/dev/null; then
      echo
      echo "Root privileges required to uninstall plugin..."
    fi
    sudo rm -rf "$path"
  else
    rm -rf "$path"
  fi
}

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
  
  if curl -fsSL "$REPO_RAW_URL/install.sh" -o "$TMP" &&
    env -i HOME="$BASE" USER="$USER_NAME" SUDO_USER="${SUDO_USER:-}" PATH="$PATH" bash "$TMP" --update --yes; then
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
  REMOTE_VERSION=""

  if ! check_for_update; then
    if [[ "$UI_MODE" == "whiptail" ]]; then
      whiptail --title "Update check" \
        --msgbox "Failed to fetch latest version." 10 60
    else
      echo "Failed to fetch latest version."
      read -rp "Press Enter to continue..."
    fi
    return
  fi

  if [[ "$REMOTE_VERSION" == "$VERSION" ]]; then
    if [[ "$UI_MODE" == "whiptail" ]]; then
      whiptail --title "Update check" \
        --msgbox "You are already up to date." 10 60
    else
      echo "You are already up to date."
      read -rp "Press Enter to continue..."
    fi
    return
  fi

  if [[ "$UI_MODE" == "whiptail" ]]; then
    whiptail --title "Update available" \
      --yesno "Update available.\n\nCurrent: $VERSION\nLatest: $REMOTE_VERSION\n\nUpdate now?" 12 60

    if [[ $? -eq 0 ]]; then
      install_update
    fi
  else
    echo "Update available."
    echo "Current: $VERSION"
    echo "Latest: $REMOTE_VERSION"
    echo
    read -rp "Update now? [y/N]: " ans
    [[ "$ans" == "y" || "$ans" == "yes" ]] && install_update
  fi
}

build_plugin_list() {
  declare -n _options="$1"
  declare -n _map="$2"

  local f name display

  local all_plugins=()

  # collect enabled
  for f in "$PLUG"/*; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    all_plugins+=("$name|$f|enabled")
  done

  # collect disabled
  for f in "$DIS"/*; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    all_plugins+=("$name|$f|disabled")
  done

  # sort alphabetically by plugin name
  IFS=$'\n' sorted=($(sort <<<"${all_plugins[*]}"))
  unset IFS

  # rebuild output
  for entry in "${sorted[@]}"; do
    IFS='|' read -r name path state <<< "$entry"
    display="$name ($([[ "$state" == "enabled" ]] && echo "Enabled" || echo "Disabled"))"
    _options+=("$display")
    _map["$display"]="$path|$state"
  done
}

show_result() {
  clear
  echo "$1"
  echo
  read -rp "Press Enter to continue..."
}

uninstall_plugin_menu_loop() {
  while true; do
    clear

    declare -A map=()
    declare -a options=()

    options+=("Go back" "Return to main menu")
    build_plugin_list options map

    opt=$(ui_menu \
      "Uninstall Plugins" \
      "Select a plugin to uninstall" \
      20 \
      "${options[@]}"
    )

    # CLI fallback
    if [[ "$UI_MODE" == "cli" ]]; then
      [[ "$opt" =~ ^[0-9]+$ ]] || continue
      opt="${options[$((opt-1))]}"
    fi

    [[ "$opt" == "Go back" ]] && return
    [[ -z "$opt" ]] && continue

    IFS='|' read -r path state <<< "${map[$opt]}"
    name=$(basename "$path")

    if ! ui_confirm "Confirm uninstall" "Uninstall $name?"; then
      show_result "Uninstall cancelled"
      continue
    fi

    uninstall_plugin "$path"
    show_result "$name uninstalled"
  done
}

plugin_menu_loop() {
  while true; do
    clear

    declare -A map=()
    declare -a options=()

    options+=("Go back" "Return to main menu")
    build_plugin_list options map

    opt=$(ui_menu \
      "Plugins" \
      "Enable / disable plugins" \
      20 \
      "${options[@]}"
    )

    # CLI fallback: convert numeric input to option
    if [[ "$UI_MODE" == "cli" ]]; then
      [[ "$opt" =~ ^[0-9]+$ ]] || continue
      opt="${options[$((opt-1))]}"
    fi

    [[ "$opt" == "Go back" ]] && return
    [[ -z "$opt" ]] && continue

    IFS='|' read -r path state <<< "${map[$opt]}"
    name=$(basename "$path")

    if [[ "$state" == "enabled" ]]; then
      move "$path" "$DIS/$name"
      show_result "$name disabled"
    else
      move "$path" "$PLUG/$name"
      show_result "$name enabled"
    fi
  done
}

main_menu() {
  while true; do

    opt=$(ui_menu \
      "Decky Plugin Manager $VERSION" \
      "Select an option" \
      4 \
      "1" "Enable/disable plugins" \
      "2" "Uninstall plugins" \
      "3" "Check for update" \
      "4" "Exit"
    )

    if [[ "$UI_MODE" == "whiptail" ]]; then
      exit_status=$?
      if [[ $exit_status -ne 0 ]]; then
        exit 0
      fi
    fi

    case "$opt" in
      1) plugin_menu_loop ;;
      2) uninstall_plugin_menu_loop ;;
      3) handle_update_check ;;
      4) exit 0 ;;
    esac

  done
}

init_paths
main_menu
