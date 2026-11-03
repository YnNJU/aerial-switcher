import AerialCore
import Foundation
import Observation

enum AppLanguage: String, CaseIterable {
    case system, english = "en", chinese = "zh-Hans"

    /// Each language by its own name, so it can be found whatever is showing now.
    @MainActor var name: String {
        switch self {
        case .system: tr("System")
        case .english: "English"
        case .chinese: "简体中文"
        }
    }
}

/// The language the app is shown in: the system's, or one picked in Settings. Views
/// that call `tr` read it, so they redraw when it changes.
@MainActor @Observable
final class Localization {
    static let shared = Localization()

    var language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .system {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
    }

    /// For names that come from macOS, such as the sets'.
    var preferredLanguages: [String] {
        language == .system ? Locale.preferredLanguages : [language.rawValue]
    }

    var locale: Locale {
        language == .system ? .autoupdatingCurrent : Locale(identifier: language.rawValue)
    }

    fileprivate var isChinese: Bool {
        Bundle.preferredLocalizations(from: ["en", "zh-Hans"], forPreferences: preferredLanguages).first == "zh-Hans"
    }
}

/// `english` in the app's language; with `args`, a format like String(format:) takes.
@MainActor
func tr(_ english: String, _ args: CVarArg...) -> String {
    let format = Localization.shared.isChinese ? chinese[english] ?? english : english
    return args.isEmpty ? format : String(format: format, locale: Localization.shared.locale, arguments: args)
}

extension DayPhase {
    @MainActor var name: String { tr(title) }
}

private let chinese: [String: String] = [
    // Settings
    "Aerials": "航拍",
    "General": "通用",
    "About": "关于",
    "Set": "壁纸组",
    "Choose…": "选择…",
    "One place, filmed at different times of day.": "同一地点，在一天中不同时段拍摄。",
    "Downloading %1$@ of %2$@": "正在下载第 %1$@ 个，共 %2$@ 个",
    "Schedule": "时间",
    "Reset to Defaults": "恢复默认",
    "Drag a handle to change when that part of the day begins.": "拖动把手，调整各时段的开始时间。",
    "%1$@ starts at %2$@": "%1$@从 %2$@ 开始",
    "Startup": "启动",
    "Launch at Login": "登录时打开",
    "Wallpaper": "壁纸",
    "Switch Wallpaper": "切换壁纸",
    "When off, the wallpaper you had before is put back.": "关闭后恢复原来的壁纸。",
    "Pause": "暂停",
    "Keeps the Aerial showing now until unpaused.": "保留当前的航拍，直到取消暂停。",
    "Language": "语言",
    "System": "跟随系统",
    "Version %@": "版本 %@",
    "Automatically switch aerial wallpaper with the time of day.": "让航拍壁纸随时间自动切换。",
    "Aerial Switcher on GitHub": "GitHub 上的 Aerial Switcher",

    // Menu
    "Choose a set below": "在下方选择壁纸组",
    "Downloading %1$@ of %2$@ · %3$@%%": "正在下载 %1$@/%2$@ · %3$@%%",
    "Off · original wallpaper": "已关闭 · 原来的壁纸",
    "Paused": "已暂停",
    "%1$@ at %2$@": "%2$@ 切换到%1$@",
    "Settings…": "设置…",
    "Quit Aerial Switcher": "退出 Aerial Switcher",

    // Sets: macOS leaves some names in English
    "Golden Gate": "金门海峡",
    "Tahoe": "太浩湖",
    "Sequoia": "红杉国家公园",

    // Times of day
    "Sunrise": "日出",
    "Morning": "清晨",
    "Day": "白天",
    "Sunset": "日落",
    "Evening": "傍晚",
    "Night": "夜晚",

    // Errors
    "Couldn't change Launch at Login: %@": "无法更改登录时打开：%@",
    "Couldn't save settings: %@": "无法保存设置：%@",
    "Downloading %1$@ failed: %2$@": "下载 %1$@ 失败：%2$@",
    "Couldn't read the Aerial manifest. Open System Settings › Wallpaper once so macOS downloads it.":
        "无法读取航拍清单。请先打开一次“系统设置 › 墙纸”，让 macOS 下载它。",
    "The Aerial manifest has an unexpected format.": "航拍清单的格式无法识别。",
    "No wallpaper entries were found in the wallpaper store.": "壁纸配置中没有找到壁纸。",
    "Couldn't read the wallpaper store.": "无法读取壁纸配置。",
]
