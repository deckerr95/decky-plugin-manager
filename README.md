# Decky Plugin Manager

A simple CLI tool to individually enable/disable Decky Loader plugins. Useful when a single broken plugin prevents Decky from loading after SteamOS updates.

---

## Features
- Enable / disable individual Decky plugins
- Prevent full Decky breakage from a single bad plugin
- Lightweight CLI interface
- Works directly with Decky plugin directories
- Optional uninstall support

---

## Installation

### Recommended (safe install via script download)

```bash
curl -fsSL http://IP:8000/install.sh -o /tmp/dpm-install.sh && bash /tmp/dpm-install.sh
```

---

### Alternative (short form)

```bash
bash <(curl -fsSL http://IP:8000/install.sh)
```

---

## Desktop launcher (Steam Deck friendly)

Download and run:

[Install Decky Plugin Manager](http://192.168.1.118:8000/install-decky-plugin-manager.desktop)

This provides a one-click installer usable from Desktop Mode.

---

## Usage

After installation:

```bash
decky-plugin-manager
```

or:

```bash
dpm
```

---

## Uninstall

Run:

```bash
decky-plugin-manager --uninstall
```

This removes:

* Installed binary
* Symlink (`dpm`)

---

## Default install location

```bash
~/.local/bin/decky-plugin-manager
~/.local/bin/dpm
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
  * `~/homebrew/disabled`
* Moves plugin folders between them to enable/disable
* Changes take effect after restarting Steam / Decky Loader

---

## Notes

* A broken plugin can crash Decky Loader; this tool isolates that issue
* Designed for Steam Deck / SteamOS but works on any Linux setup with Decky Loader
* Installation script pulls latest version

---

## Troubleshooting

If installation fails:

* Verify network access to install URL
* Ensure `curl` is installed
* Check that the install script server is reachable

If plugins do not appear:

```bash
~/homebrew/plugins
```

must exist and contain Decky plugins.

---

## Security note

The installer executes remote code. Only use trusted sources (official GitHub releases or self-hosted trusted server).

```
```
