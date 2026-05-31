# Decky Plugin Manager

A user-friendly tool to individually enable/disable [Decky Loader](https://github.com/SteamDeckHomebrew/decky-loader) plugins. Features a graphical interface (whiptail) with CLI fallback. Essential when a single broken plugin prevents Decky from loading after SteamOS updates.

---

## Features
- Enable / disable individual Decky plugins
- Prevent full Decky breakage from a single bad plugin
- User-friendly GUI interface using whiptail (primary) with CLI fallback
- Graphical menus and dialogs for easy navigation
- Works directly with Decky plugin directories
- Adds desktop launchers for the main tool, as well as the uninstaller, for easy access
- Easy installation and uninstallation
- Built-in update checking system

---

## Interface

The tool provides a user-friendly interface with two modes:

### Primary: Whiptail GUI (Recommended)
- **Graphical menus and dialogs** for easy navigation
- **Checklist interface** for selecting multiple plugins
- **Password prompts** via secure passwordbox for sudo authentication
- **Progress indicators** and visual feedback
- **Automatic detection**: Used when `whiptail` command is available and terminal is interactive

### Fallback: CLI Mode
- **Text-based interface** for systems without whiptail
- **Simple numbered menu** for plugin selection
- **Terminal input** for password prompts
- **Basic but functional**: Provides core functionality when GUI is unavailable

**Note**: Whiptail is detected at runtime, not installation time. The script automatically uses the best available interface for your system.

---

## Installation

### Steam Deck friendly

Provides a one-click installer from Desktop Mode. Follow these simple steps:

1. **Download the desktop launcher:**
   [Install Decky Plugin Manager](http://192.168.1.161:8000/install-decky-plugin-manager.desktop)

2. **Open in file manager (Dolphin)**: Navigate to your Downloads folder and double-click the `.desktop` file

3. **Follow installer prompts**: The installer will guide you through the process with clear instructions

4. **Complete installation**: The tool will be installed to `~/.local/bin/` and desktop launchers will be created for easy access

**Note**: The installer supports both fresh installation and updating existing installations. It checks for existing versions and prompts for upgrade or reinstall as needed.

### Safe install via script download

For users who prefer terminal installation:

```bash
curl -fsSL http://192.168.1.161:8000/install.sh -o /tmp/dpm-install.sh && bash /tmp/dpm-install.sh
```

Or if you want to manually inspect the script first:

```bash
curl -fsSL http://192.168.1.161:8000/install.sh -o install.sh
# Review the script, then run:
bash install.sh
```

---

## Usage

### Starting the Manager
After installation:

**Desktop launcher (recommended):**
- `Decky Plugin Manager (DPM)` - Main application
- `Decky Plugin Manager (Uninstall)` - Uninstaller

**Terminal options:**
```bash
decky-plugin-manager
```
Or using the shorter alias:
```bash
dpm
```

### Main Menu Options
When you launch the manager, you'll see the main menu with these options:

1. **Enable Plugin(s)**
   - Move selected plugins from `~/homebrew.disabled` to `~/homebrew/plugins`
   - Select one or multiple plugins using the interface

2. **Disable Plugin(s)**
   - Move selected plugins from `~/homebrew/plugins` to `~/homebrew.disabled`
   - Isolate problematic plugins without deleting them

3. **Enable All Plugins**
   - Move all disabled plugins back to active directory
   - Useful after fixing plugin issues or SteamOS updates

4. **Disable All Plugins**
   - Move all plugins to disabled directory
   - Last resort when Decky won't load and you need to identify the culprit

5. **Uninstall Plugin(s)**
   - **WARNING**: Permanently deletes selected plugins
   - Removes plugin folders and all associated files
   - Use with caution - data cannot be recovered

6. **Check for Updates**
   - Compare local version with remote version file
   - Automatically download and install updates if available
   - Maintains your plugin configurations during update

7. **Exit**
   - Close the manager and return to desktop/terminal

### Typical User Flow
1. **Launch** from desktop launcher or terminal
2. **Select action** from main menu (enable/disable plugins, check updates, etc.)
3. **Choose plugins** using the interactive selection interface
4. **Confirm changes** when prompted
5. **View results** with success/failure messages
6. **Restart Steam/Decky Loader** for changes to take effect

### Tips for Effective Use
- **Start with disabling** suspected problematic plugins first
- **Enable one at a time** after SteamOS updates to identify broken plugins
- **Use "Disable All"** when Decky won't load at all, then enable plugins gradually
- **Check for updates regularly** to ensure you have the latest features and fixes

---

## Update System

The tool includes built-in update checking functionality:

### Update Checking
- **Version comparison**: Compares local version against remote `version` file
- **Simple mechanism**: Currently checks only version difference (future improvements may add more robust checking)
- **Automatic checks**: Can be triggered from the main menu's "Check for updates" option

### Update Process
- When an update is available, the tool downloads and executes the installer with `--update --yes` flags
- **Preserves settings**: Update process maintains your plugin configurations and preferences
- **Minimal disruption**: Updates are applied quickly with minimal user interaction

### Manual Update
You can also update manually by re-running the installation script:

```bash
curl -fsSL http://192.168.1.161:8000/install.sh -o /tmp/dpm-install.sh && bash /tmp/dpm-install.sh
```

**Note**: The update system is designed to be simple and reliable, focusing on the essential function of keeping the tool current.

---

## Uninstall

Run the desktop launcher `Decky Plugin Manager (Uninstall)`

Or run:

```bash
decky-plugin-manager --uninstall
```

This removes:

* Installed binary
* Symlink (`dpm`)

---

## Install location

Main binary + symlink:

```bash
~/.local/bin/decky-plugin-manager
~/.local/bin/dpm
```

Desktop launchers:

```bash
~/.local/share/applications/dpm.desktop
~/.local/share/applications/dpm-uninstall.desktop
```

Ensure this directory is in PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

---

## Requirements

### Essential
* **bash** - Shell environment
* **curl** - For downloading the installer (already available on Steam Deck/Bazzite)
* **sudo** - Required when plugin directories are root-owned (common after manual Decky installation)

### Recommended for Full GUI Experience
* **whiptail** - Provides graphical menus and dialogs (primary interface)
  * Automatically detected at runtime
  * CLI fallback available if whiptail is not installed

### Notes
* sudo prompts are cached for a few minutes after authentication (standard sudo behavior)
* The tool automatically uses the best available interface for your system
* curl requirement note removed - all target distributions (SteamOS, Bazzite) have curl pre-installed

---

## How it works

The manager provides a simple but effective plugin management system:

### Plugin Toggling Mechanism
- **Scans Decky plugin directories**:
  - `~/homebrew/plugins` (active plugins)
  - `~/homebrew.disabled` (disabled plugins, created automatically if missing)
- **Moves plugin folders** between these directories to enable/disable functionality
- **Changes take effect** after restarting Steam / Decky Loader

### Root Ownership Handling
- When plugin directories are owned by root (common after manual Decky installation), the tool will prompt for sudo password
- Uses `ensure_sudo()` function to cache authentication temporarily using system sudo cache
- Password prompts appear via whiptail passwordbox (GUI) or terminal input (CLI fallback)

### Directory Management
- Automatically creates `~/homebrew.disabled` directory if it doesn't exist
- Preserves all plugin files and configurations when moving between directories
- Future improvements could optimize root permission handling for smoother operation

---

## Purpose of this project

It's a common occurrence after a SteamOS update that some Decky plugins are not updated in time. This results in Decky crashing. For users, the only real options to fix this are:

1. Going into desktop mode, opening a terminal, and deleting the plugin dir from `/home/deck/homebrew/plugins/`

2. SSH-ing into the deck, and deleting the plugin

This project aims to provide a seamless, quick and easy way of disabling/enabling individual Decky plugins.

---

## Troubleshooting

### Common Issues

#### Installation Issues
* **Desktop launchers not appearing after installation**
  * Run `kbuildsycoca5` or `kbuildsycoca6` to refresh KDE desktop cache
  * Log out and back into Desktop Mode
* **Installation script fails**
  * Ensure you have internet connectivity
  * Check that the server `http://192.168.1.161:8000` is accessible

#### Plugin Management Issues
* **No plugins appear in the manager**
  1. **Decky Loader not installed**: Ensure `~/homebrew/plugins` directory exists
  2. **No plugins installed**: Install plugins through Decky Loader first
  3. **Permission issues**: Check if plugin directories are accessible
* **Permission errors when moving plugins**
  * Plugin directories owned by root: sudo password will be prompted
  * Ensure you have sudo privileges on your system
  * Check `~/homebrew/plugins` ownership with `ls -la ~/homebrew/`
* **Changes not taking effect**
  * Restart Steam / Decky Loader for changes to apply
  * Ensure plugin folders are being moved correctly between `~/homebrew/plugins` and `~/homebrew.disabled`

#### Update Issues
* **Update check failures**
  * Network connectivity issues
  * Server `http://192.168.1.161:8000` may be unavailable
  * Check internet connection and try again later

#### Interface Issues
* **Whiptail not working or showing basic interface**
  * Whiptail may not be installed on your system
  * Non-interactive terminal session (CLI fallback will be used)
  * Install whiptail for full GUI experience: `sudo pacman -S whiptail` (Arch-based) or `sudo apt install whiptail` (Debian-based)

---

## Notes

* **Plugin safety**: A broken plugin can crash Decky Loader; this tool isolates that issue without deleting your plugins
* **Testing status**: Tested on Bazzite and SteamOS (latest versions)
* **Automatic updates**: Installation script pulls the latest version from the server
* **Directory management**: Automatically creates `~/homebrew.disabled` directory if it doesn't exist
* **KDE integration**: Installer calls `kbuildsycoca5` or `kbuildsycoca6` to refresh desktop launcher cache
* **Path handling**: Installs to `~/.local/bin/` for user installation without requiring system-wide permissions

---
## Disclaimer

The author of this tool is not responsible for any damage, data loss, or software breakage that may occur from using this tool.
Use at your own risk. Always backup your data before making changes to your system.

This tool is provided as-is without any warranty, express or implied, including but not limited to the warranties of merchantability,
fitness for a particular purpose and noninfringement. In no event shall the author be liable for any claim, damages or other liability,
whether in an action of contract, tort or otherwise, arising from, out of or in connection with the tool or the use or other dealings in the tool.