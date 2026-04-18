# Aerial Switcher

> A CLI tool that switches macOS Aerial wallpapers by directly modifying the wallpaper store.

## Introduction

`aerial-switcher` works by rewriting macOS's Aerial wallpaper store and optionally restarting `WallpaperAgent`.

It uses a LaunchAgent to schedule switching. Combos and time points are generated dynamically from `.make-settings`.

**Currently supports:**

- Wallpaper combos: `tahoe`, `sequoia`
- Custom switching time points

## Requirements

- macOS 15+
- Swift toolchain

## Installation

```bash
git clone https://github.com/YnNJU/aerial-switcher.git
cd aerial-switcher
make install
```

## Usage

Use the following `make` commands:

|Command|Description|
|---|---|
|`make install`|Build, install, enable, and run once|
|`make uninstall`|Disable and remove the LaunchAgent plist|
|`make enable`|Enable the installed LaunchAgent|
|`make disable`|Disable the LaunchAgent|
|`make combo`|Choose Tahoe or Sequoia combo|
|`make time`|Change saved HHmm time points for the current combo|
|`make default`|Reset time points to defaults|
|`make reload`|Re-enable the LaunchAgent|
|`make help`|Show this help|

> Saved settings live in `.make-settings`.

## Notes

- This is a hack. It depends on macOS's current Aerial implementation (manifest, store layout, provider ID, labels). If Apple changes any of these, it may break.
- Aerial wallpapers must already exist on the machine.
