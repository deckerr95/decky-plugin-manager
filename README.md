# Decky Plugin Manager

A simple CLI tool to individually enable/disable [Decky Loader](https://github.com/SteamDeckHomebrew/decky-loader) plugins. Useful when a single broken plugin prevents Decky from loading after SteamOS updates.

---

## Features
- Enable / disable individual Decky plugins
- Prevent full Decky breakage from a single bad plugin
- Lightweight CLI interface
- Works directly with Decky plugin directories
- Adds desktop launchers for the main tool, as well as the uninstaller, for easy access
- Easy installation and uninstallation

---

## Installation

### Steam Deck friendly

Download and run:

[Install Decky Plugin Manager](http://192.168.1.161:8000/install-decky-plugin-manager.desktop)

This provides a one-click installer usable from Desktop Mode.

---

### Safe install via script download

```bash
curl -fsSL http://IP:8000/install.sh -o /tmp/dpm-install.sh && bash /tmp/dpm-install.sh
```

---

## Usage

After installation:

Start via `Decky Plugin Manager (DPM)` desktop launcher

Or from terminal:

```bash
decky-plugin-manager
```

Or:

```bash
dpm
```

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

* bash
* curl
* sudo (only required when moving plugins in Decky directories)

---

## How it works

* Scans Decky plugin directories:

  * `~/homebrew/plugins`
  * `~/homebrew.disabled` (created by DPM)
* Moves plugin folders between them to enable/disable
* Changes take effect after restarting Steam / Decky Loader

---

## Purpose of this project

It's a common occurrence after a SteamOS update that some Decky plugins are not updated in time. This results in Decky crashing. For users, the only real options to fix this are:

1. Going into desktop mode, opening a terminal, and deleting the plugin dir from `/home/deck/homebrew/plugins/`

2. SSH-ing into the deck, and deleting the plugin

This project aims to provide a seamless, quick and easy way of disabling/enabling individual Decky plugins.

---

## Notes

* A broken plugin can crash Decky Loader; this tool isolates that issue
* Tested only on Bazzite for Steam Deck. Should also work on SteamOS.
* Installation script pulls latest version

---

## Troubleshooting

If installation fails:

* Ensure `curl` is installed

If plugins do not appear:

```bash
~/homebrew/plugins
```

must exist and contain Decky plugins.
