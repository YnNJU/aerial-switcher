<p align="center">
  <img src="Assets/icon.png" width="128" alt="Aerial Switcher icon">
</p>

<h1 align="center">Aerial Switcher</h1>

<p align="center">
  Automatically switch aerial wallpaper with the time of day.<br>
  <a href="README.zh-CN.md">简体中文</a>
</p>

---

Some of the Landscape aerial wallpapers included with macOS come in sets showing the same location at different times of day. Tahoe, Sequoia, and Golden Gate are examples, but macOS doesn't automatically switch between them.

Aerial Switcher is a menu bar app that switches between these wallpapers at scheduled times.

<p align="center">
  <img src="Assets/settings.png" width="460" alt="Settings window">
</p>

## Features

- **Scheduled switching**: Automatically switches wallpapers within a set, including syncing after startup, wake, and login.
- **Custom times**: Drag the handles on a 24-hour timeline to adjust when each period begins.
- **Automatic downloads**: Downloads videos that aren't installed yet.
- **Easy to undo**: Pause to keep the current aerial, or turn switching off to restore your previous wallpaper.
- **Out of the way**: A single menu bar icon shows the current period, with optional launch at login.

## Installation
Requires macOS 15 or later.

1. Download the latest `AerialSwitcher-x.y.z.zip` from [Releases](https://github.com/YnNJU/aerial-switcher/releases) and unzip it.
2. Move **Aerial Switcher** to the Applications folder and open it.

The app is not currently notarized by Apple, so macOS may block it on first launch. Go to **System Settings › Privacy & Security**, scroll down, and select **Open Anyway**.

## Usage

The Settings window opens on first launch. Choose a wallpaper set; the app will download any missing videos and switch to the wallpaper for the current time of day.

After that, use the menu bar icon to change wallpaper sets, pause or disable automatic switching, and adjust the time settings.

If the menu bar icon is hidden, open the app again to bring up Settings.

Default switching times:

- Morning: 06:00
- Day: 12:00
- Sunset: 17:00
- Evening: 18:00
- Night: 21:00

All times can be adjusted in Settings.

## Implementation

macOS stores wallpaper settings in:

 `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist`

Aerial Switcher updates this configuration at the scheduled time and restarts `WallpaperAgent` to apply the change.

The app backs up your existing configuration before taking over. Turning off automatic switching restores your previous wallpaper; if you've manually changed your wallpaper in the meantime, your change is preserved.

Missing aerial videos are downloaded from Apple's servers to the system directory:

 `~/Library/Application Support/com.apple.wallpaper/aerials/videos`

**Note:** This approach relies on undocumented macOS wallpaper configuration mechanisms. Future macOS updates may break it. If you encounter a problem, please [open an issue](https://github.com/YnNJU/aerial-switcher/issues).

## Build from source

Install Xcode or the Command Line Tools:

```bash
git clone https://github.com/YnNJU/aerial-switcher.git
cd aerial-switcher
./scripts/bundle.sh
```

This builds a universal app in `dist/`. To run the tests:

```bash
swift test
```

If you only have the Command Line Tools installed, specify the testing plugin path manually:

```bash
swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```

## License

[MIT](LICENSE)
