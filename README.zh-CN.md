<p align="center">
  <img src="Assets/icon.png" width="128" alt="Aerial Switcher 图标">
</p>

<h1 align="center">Aerial Switcher</h1>

<p align="center">
  让航拍壁纸随时间自动切换。<br>
  <a href="README.md">English</a>
</p>

---

macOS 自带的 Landscape 航拍壁纸，有些是同一地点不同时段的成套壁纸。例如 Tahoe、Sequoia 和 Golden Gate，都有不同时段的版本，但 macOS 不能自动切换它们。

Aerial Switcher 是一个菜单栏 App，可以按照设定的时间自动切换这些壁纸。

<p align="center">
  <img src="Assets/settings.png" width="460" alt="设置窗口">
</p>

## 功能

- **按时切换**：按时间自动切换同一组航拍壁纸，支持开机、唤醒、登录后同步。
- **自定义时间**：在一条 24 小时的时间轴上拖动把手，调整各时段时间。
- **自动下载**：自动下载尚未安装的视频。
- **随时撤回**：暂停可以保留当前这段航拍；关掉切换则恢复原来的壁纸。
- **不打扰**：只有一个菜单栏图标，显示当前时段；可选开机自启。

## 安装
需要 macOS 26 或更高版本。

1. 从 [Releases](https://github.com/YnNJU/aerial-switcher/releases) 下载最新的 `AerialSwitcher-x.y.z.zip` 并解压。
2. 把 **Aerial Switcher** 拖进「应用程序」文件夹，然后打开。

应用目前未经 Apple 公证，首次启动可能被 macOS 拦截，可以在「系统设置 › 隐私与安全性」，滚动到下方，选择「**仍要打开」**。

## 使用

首次启动时会打开设置窗口。选择壁纸组后，应用会自动下载缺少的视频，并切换至当前时段对应的壁纸。

之后可以通过菜单栏图标切换壁纸组、暂停或关闭自动切换，以及修改时间设置。

如果菜单栏图标被隐藏，重新打开应用即可进入设置窗口。

默认切换时间为：

- 清晨：06:00
- 白天：12:00
- 日落：17:00
- 傍晚：18:00
- 夜晚：21:00

所有时间均可在设置中调整。

## 实现

macOS 把壁纸设置存在：

 `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist`

Aerial Switcher 在指定时间更新配置，并重启 `WallpaperAgent` 生效。

应用会在接管壁纸前备份原有配置。关闭自动切换时恢复原有壁纸；如果用户期间手动修改过壁纸，则保留用户的修改。

缺少的航拍视频从 Apple 服务器下载至系统目录：

 `~/Library/Application Support/com.apple.wallpaper/aerials/videos`

**注意：**这些做法依赖 macOS 未公开的壁纸配置机制，未来的系统更新可能让它失效。遇到问题请[提 issue](https://github.com/YnNJU/aerial-switcher/issues)。

## 从源码构建

需要安装 Xcode 或命令行工具（Command Line Tools）：

```bash
git clone https://github.com/YnNJU/aerial-switcher.git
cd aerial-switcher
./scripts/bundle.sh
```

会在 `dist/` 下生成通用二进制（Universal）的 App。运行测试：

```bash
swift test
```

如果只装了命令行工具，需要手动指定测试插件的路径：

```bash
swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```

## 许可证

[MIT](LICENSE)
