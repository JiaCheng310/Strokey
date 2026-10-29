// 配置文件：~/.config/strokey/config.json（首次运行自动生成，缺少的新字段会自动补全）

import Foundation

/// 界面文字：系统语言是中文时用中文，否则用英文
func L(_ zh: String, _ en: String) -> String { isChinese ? zh : en }
private let isChinese = Locale.preferredLanguages.first?.hasPrefix("zh") ?? false

/// 一个动作：快捷键、shell 命令或内置动作，三选一（也可以组合）
struct Action: Codable {
    var name: String?
    var key: String?      // 例如 "cmd+shift+t"
    var shell: String?    // 例如 "open -a Safari"
    var action: String?   // 内置动作，例如 "missionControl"，完整列表见 Actions.swift

    var label: String { name ?? action ?? key ?? shell ?? "" }
}

/// 中键 / 侧键：单击动作 + 按住拖动的手势
struct ButtonConfig: Codable {
    var click: Action?
    var drag: [String: Action]?
}

/// 按住右键滚滚轮
struct WheelGesture: Codable {
    var up: Action?
    var down: Action?
}

/// 摇杆手势：按住一个键再点另一个键
struct Rocker: Codable {
    var rightThenLeft: Action?   // 按住右键，点左键
    var leftThenRight: Action?   // 按住左键，点右键
}

struct ScrollConfig: Codable {
    var enabled = true
    var reverse = false        // 只反转鼠标滚轮，触控板不受影响
    var speed = 1.0
    var smoothness = 0.25      // 一格滚动的动画时长（秒），越大越顺滑
    var acceleration = true    // 连续快速滚动时加速

    init() {}

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let def = ScrollConfig()
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? def.enabled
        reverse = try c.decodeIfPresent(Bool.self, forKey: .reverse) ?? def.reverse
        speed = try c.decodeIfPresent(Double.self, forKey: .speed) ?? def.speed
        smoothness = try c.decodeIfPresent(Double.self, forKey: .smoothness) ?? def.smoothness
        acceleration = try c.decodeIfPresent(Bool.self, forKey: .acceleration) ?? def.acceleration
    }
}

struct Config: Codable {
    var minStroke = 30.0           // 识别为一笔的最小移动距离（像素）
    var showTrail = true
    var excludeApps: [String] = [] // 这些 App 在前台时不拦截鼠标按键
    var global: [String: Action] = [:]               // 右键手势
    var apps: [String: [String: Action]] = [:]       // 按 bundle id 覆盖右键手势
    var buttons: [String: ButtonConfig] = [:]        // "2" 中键，"3" "4" 侧键
    var wheelGesture = WheelGesture()
    var rocker = Rocker()
    var scroll = ScrollConfig()

    init() {}

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let def = Config.defaults
        minStroke = try c.decodeIfPresent(Double.self, forKey: .minStroke) ?? def.minStroke
        showTrail = try c.decodeIfPresent(Bool.self, forKey: .showTrail) ?? def.showTrail
        excludeApps = try c.decodeIfPresent([String].self, forKey: .excludeApps) ?? def.excludeApps
        global = try c.decodeIfPresent([String: Action].self, forKey: .global) ?? def.global
        apps = try c.decodeIfPresent([String: [String: Action]].self, forKey: .apps) ?? def.apps
        buttons = try c.decodeIfPresent([String: ButtonConfig].self, forKey: .buttons) ?? def.buttons
        wheelGesture = try c.decodeIfPresent(WheelGesture.self, forKey: .wheelGesture) ?? def.wheelGesture
        rocker = try c.decodeIfPresent(Rocker.self, forKey: .rocker) ?? def.rocker
        scroll = try c.decodeIfPresent(ScrollConfig.self, forKey: .scroll) ?? def.scroll
    }

    static var defaults: Config {
        var c = Config()
        c.global = [
            "L":  Action(name: L("后退", "Back"), action: "back"),
            "R":  Action(name: L("前进", "Forward"), action: "forward"),
            "U":  Action(name: L("回到顶部", "Scroll to top"), action: "scrollTop"),
            "D":  Action(name: L("到底部", "Scroll to bottom"), action: "scrollBottom"),
            "DR": Action(name: L("关闭标签页", "Close tab"), key: "cmd+w"),
            "DL": Action(name: L("恢复关闭的标签页", "Reopen closed tab"), key: "cmd+shift+t"),
            "UD": Action(name: L("刷新", "Reload"), key: "cmd+r"),
            "UL": Action(name: L("上一个标签页", "Previous tab"), key: "ctrl+shift+tab"),
            "UR": Action(name: L("下一个标签页", "Next tab"), key: "ctrl+tab"),
            "RD": Action(name: L("最小化窗口", "Minimize window"), action: "windowMinimize"),
            "RU": Action(name: L("窗口最大化", "Maximize window"), action: "windowMaximize"),
            "LDR": Action(name: L("窗口放左半屏", "Tile window left"), action: "windowLeft"),
            "RDL": Action(name: L("窗口放右半屏", "Tile window right"), action: "windowRight"),
        ]
        c.buttons = [
            // 中键：单击保持原样（浏览器里新标签打开链接），按住拖动切桌面，往哪拖就去哪边
            "2": ButtonConfig(drag: [
                "U": Action(name: L("调度中心", "Mission Control"), action: "missionControl"),
                "D": Action(name: L("当前 App 的所有窗口", "App windows"), action: "appExpose"),
                "L": Action(name: L("左边的桌面", "Desktop on the left"), action: "spaceLeft"),
                "R": Action(name: L("右边的桌面", "Desktop on the right"), action: "spaceRight"),
            ]),
            "3": ButtonConfig(click: Action(name: L("后退", "Back"), action: "back")),
            "4": ButtonConfig(click: Action(name: L("前进", "Forward"), action: "forward")),
        ]
        c.wheelGesture = WheelGesture(
            up: Action(name: L("上一个标签页", "Previous tab"), key: "ctrl+shift+tab"),
            down: Action(name: L("下一个标签页", "Next tab"), key: "ctrl+tab"))
        c.rocker = Rocker(
            rightThenLeft: Action(name: L("后退", "Back"), action: "back"),
            leftThenRight: Action(name: L("前进", "Forward"), action: "forward"))
        return c
    }
}

let configURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config/strokey/config.json")

/// 项目改名前（MouseGesture）的配置位置，首次启动时迁移过来
private let legacyConfigURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config/mousegesture/config.json")

func saveConfig(_ cfg: Config) {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try? FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? enc.encode(cfg).write(to: configURL)
}

func loadConfig() -> Config {
    let fm = FileManager.default
    if !fm.fileExists(atPath: configURL.path) && fm.fileExists(atPath: legacyConfigURL.path) {
        try? fm.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? fm.copyItem(at: legacyConfigURL, to: configURL)
    }
    guard let data = try? Data(contentsOf: configURL) else {
        saveConfig(.defaults)
        return .defaults
    }
    do {
        let cfg = try JSONDecoder().decode(Config.self, from: data)
        // 旧配置缺少新字段时，把补全后的配置写回去，让新选项在文件里可见
        if let old = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let full = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(cfg)) as? [String: Any],
           Set(old.keys) != Set(full.keys) {
            saveConfig(cfg)
        }
        return cfg
    } catch {
        logger.error("配置解析失败，使用默认配置: \(error.localizedDescription, privacy: .public)")
        return .defaults
    }
}
