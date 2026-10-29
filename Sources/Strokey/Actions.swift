// 动作执行：快捷键模拟、shell 命令、内置动作

import Cocoa
import ApplicationServices
import Carbon
import os

// 标记我们自己发出的事件，避免被自己的 event tap 再次拦截
let kSelfMarker: Int64 = 0x4D47_5354

// 查看日志：log stream --predicate 'subsystem == "io.github.jiacheng310.strokey"'
let logger = Logger(subsystem: "io.github.jiacheng310.strokey", category: "main")

// 动作在后台串行队列里执行：窗口管理要和其他 App 通信，对方卡住时不能拖慢 event tap
private let actionQueue = DispatchQueue(label: "io.github.jiacheng310.strokey.actions", qos: .userInteractive)

func perform(_ a: Action) {
    let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?"
    actionQueue.async {
        logger.info("执行动作: \(a.label, privacy: .public)（前台 App: \(app, privacy: .public)）")
        if let k = a.key { sendKeyCombo(k) }
        if let s = a.shell { runShell(s) }
        if let b = a.action { performBuiltin(b) }
    }
}

// MARK: - 内置动作

func performBuiltin(_ name: String) {
    switch name {
    case "missionControl": dockNotify("com.apple.expose.awake", fallbackApp: "Mission Control")
    case "appExpose":      dockNotify("com.apple.expose.front.awake", fallbackApp: "Mission Control")
    case "showDesktop":    dockNotify("com.apple.showdesktop.awake", fallbackApp: nil)
    case "launchpad":
        // macOS 26 起启动台换成了「应用程序」App
        if FileManager.default.fileExists(atPath: "/System/Applications/Launchpad.app") {
            dockNotify("com.apple.launchpad.toggle", fallbackApp: "Launchpad")
        } else {
            openSystemApp("Apps")
        }
    case "back":           navigate(forward: false)
    case "forward":        navigate(forward: true)

    case "scrollTop":      scrollToEdge(top: true)
    case "scrollBottom":   scrollToEdge(top: false)

    case "spaceLeft":      switchSpace(right: false)
    case "spaceRight":     switchSpace(right: true)

    case "windowLeft":
        moveFocusedWindow { vf, _ in NSRect(x: vf.minX, y: vf.minY, width: vf.width / 2, height: vf.height) }
    case "windowRight":
        moveFocusedWindow { vf, _ in NSRect(x: vf.midX, y: vf.minY, width: vf.width / 2, height: vf.height) }
    case "windowMaximize":
        moveFocusedWindow { vf, _ in vf }
    case "windowCenter":
        moveFocusedWindow { vf, size in
            let w = min(size.width, vf.width), h = min(size.height, vf.height)
            return NSRect(x: vf.midX - w / 2, y: vf.midY - h / 2, width: w, height: h)
        }
    case "windowMinimize":
        if let win = focusedWindow() {
            AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        }

    case "volumeUp":       postMediaKey(0)
    case "volumeDown":     postMediaKey(1)
    case "brightnessUp":   postMediaKey(2)
    case "brightnessDown": postMediaKey(3)
    case "mute":           postMediaKey(7)
    case "playPause":      postMediaKey(16)
    case "nextTrack":      postMediaKey(17)
    case "previousTrack":  postMediaKey(18)

    default: logger.error("未知内置动作: \(name, privacy: .public)")
    }
}

/// Dock 负责调度中心、显示桌面、启动台，通过它的通知接口触发。
/// 直接运行 Mission Control 程序在 macOS 15 上会因签名校验被系统杀掉，所以不用那种方式。
private typealias CoreDockSendNotificationFn = @convention(c) (CFString, Int32) -> Void
private let coreDockSendNotification: CoreDockSendNotificationFn? = {
    guard let h = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY),
          let sym = dlsym(h, "CoreDockSendNotification") else { return nil }
    return unsafeBitCast(sym, to: CoreDockSendNotificationFn.self)
}()

private func dockNotify(_ notification: String, fallbackApp: String?) {
    if let send = coreDockSendNotification {
        send(notification as CFString, 0)
    } else if let app = fallbackApp {
        openSystemApp(app)
    } else {
        logger.error("系统不支持 \(notification, privacy: .public)")
    }
}

private func openSystemApp(_ name: String) {
    let url = URL(fileURLWithPath: "/System/Applications/\(name).app")
    NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
        if let error { logger.error("打开 \(name, privacy: .public) 失败: \(error.localizedDescription, privacy: .public)") }
    }
}

// MARK: - 后退 / 前进

/// 这些 App 原生支持鼠标侧键前进 / 后退。对它们模拟侧键最可靠：
/// 发 ⌘[ / ⌘] 时，浏览器有时不认（受键盘焦点、输入法等影响），侧键则和按物理侧键完全一样
private let sideButtonNavigationApps: Set<String> = [
    "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.dev", "com.google.Chrome.canary",
    "org.chromium.Chromium", "com.microsoft.edgemac", "company.thebrowser.Browser",
    "com.brave.Browser", "com.vivaldi.Vivaldi", "com.operasoftware.Opera",
    "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "app.zen-browser.zen",
    "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92", // Cursor
]

/// 其他 App（Safari、Finder 等）不认侧键，用 ⌘[ / ⌘]
private func navigate(forward: Bool) {
    let app = DispatchQueue.main.sync { NSWorkspace.shared.frontmostApplication?.bundleIdentifier } ?? ""
    if sideButtonNavigationApps.contains(app) {
        let location = CGEvent(source: nil)?.location ?? .zero
        postClick(button: forward ? 4 : 3, at: location)
    } else {
        sendKeyCombo(forward ? "cmd+]" : "cmd+[")
    }
}

/// 在指定位置发一次完整的点击（按下 + 松开）。b：1 右键，2 中键，3 / 4 侧键
func postClick(button b: Int, at p: CGPoint) {
    let types: [CGEventType] = b == 1 ? [.rightMouseDown, .rightMouseUp] : [.otherMouseDown, .otherMouseUp]
    let mb = CGMouseButton(rawValue: UInt32(b)) ?? .center
    let src = CGEventSource(stateID: .hidSystemState)
    for t in types {
        guard let ev = CGEvent(mouseEventSource: src, mouseType: t, mouseCursorPosition: p, mouseButton: mb) else { continue }
        ev.setIntegerValueField(.mouseEventButtonNumber, value: Int64(b))
        ev.setIntegerValueField(.eventSourceUserData, value: kSelfMarker)
        ev.post(tap: .cghidEventTap)
    }
}

// MARK: - 滚动到顶部 / 底部

/// 在鼠标所在位置连续发送大距离滚动。滚动事件发给鼠标下面的区域，
/// 不依赖键盘焦点：⌘↑ / ⌘↓ 在焦点位于输入框、或页面滚动区域是嵌套元素时（很多网页类 App）不起作用
private func scrollToEdge(top: Bool) {
    let step: Int32 = top ? 30_000 : -30_000
    for _ in 0..<20 {
        guard let ev = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: step, wheel2: 0, wheel3: 0) else { return }
        if let loc = CGEvent(source: nil)?.location { ev.location = loc }
        ev.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        ev.setIntegerValueField(.eventSourceUserData, value: kSelfMarker)
        ev.post(tap: .cghidEventTap)
        usleep(4_000)
    }
}

// MARK: - 桌面（Spaces）

/// SkyLight 是系统私有框架，只用来读桌面列表；查不到时不影响切换
private let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
private func skyLightSymbol<T>(_ name: String, as type: T.Type) -> T? {
    dlsym(skyLight, name).map { unsafeBitCast($0, to: type) }
}
private let slsMainConnectionID = skyLightSymbol("SLSMainConnectionID", as: (@convention(c) () -> Int32).self)
private let slsCopyManagedDisplaySpaces = skyLightSymbol(
    "SLSCopyManagedDisplaySpaces", as: (@convention(c) (Int32) -> Unmanaged<CFArray>?).self)
private let slsCopyActiveMenuBarDisplayIdentifier = skyLightSymbol(
    "SLSCopyActiveMenuBarDisplayIdentifier", as: (@convention(c) (Int32) -> Unmanaged<CFString>?).self)

/// 当前屏幕在指定方向上还有没有桌面（含全屏 App）。返回 nil 表示查不到
private func hasNeighborSpace(right: Bool) -> Bool? {
    guard let conn = slsMainConnectionID, let copySpaces = slsCopyManagedDisplaySpaces else { return nil }
    let cid = conn()
    guard let displays = copySpaces(cid)?.takeRetainedValue() as? [[String: Any]] else { return nil }
    // ⌃← / ⌃→ 作用于当前有菜单栏焦点的屏幕；所有屏幕共用桌面时只有一项
    let active = slsCopyActiveMenuBarDisplayIdentifier?(cid)?.takeRetainedValue() as String?
    guard let display = displays.first(where: { ($0["Display Identifier"] as? String) == active })
            ?? (displays.count == 1 ? displays.first : nil),
          let current = (display["Current Space"] as? [String: Any])?["id64"] as? Int,
          let ids = (display["Spaces"] as? [[String: Any]])?.compactMap({ $0["id64"] as? Int }),
          let index = ids.firstIndex(of: current) else { return nil }
    return right ? index < ids.count - 1 : index > 0
}

/// 用系统快捷键 ⌃← / ⌃→ 切换桌面（「系统设置 → 键盘 → 键盘快捷键 → 调度中心」里默认开启）
private func switchSpace(right: Bool) {
    if hasNeighborSpace(right: right) == false {
        let text = right
            ? L("已经是最右边的桌面", "Already on the rightmost desktop")
            : L("已经是最左边的桌面", "Already on the leftmost desktop")
        logger.info("\(text, privacy: .public)")
        DispatchQueue.main.async { engine.overlay.flash(text) }
        return
    }
    sendKeyCombo(right ? "ctrl+right" : "ctrl+left")
}

/// 模拟键盘上的媒体键（NX_KEYTYPE_*）
private func postMediaKey(_ key: Int) {
    for down in [true, false] {
        let state = down ? 0xA : 0xB
        let ev = NSEvent.otherEvent(
            with: .systemDefined, location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
            timestamp: 0, windowNumber: 0, context: nil,
            subtype: 8, data1: (key << 16) | (state << 8), data2: -1)
        ev?.cgEvent?.post(tap: .cghidEventTap)
    }
}

// MARK: - 窗口管理（Accessibility API）

private func focusedWindow() -> AXUIElement? {
    guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    // 默认超时是 6 秒，对方 App 卡住时别等那么久
    AXUIElementSetMessagingTimeout(axApp, 0.5)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &value) == .success,
          let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    let win = value as! AXUIElement
    AXUIElementSetMessagingTimeout(win, 0.5)
    return win
}

/// layout 收到窗口所在屏幕的可用区域和窗口当前尺寸（Cocoa 坐标，左下原点），返回目标位置
private func moveFocusedWindow(_ layout: (NSRect, CGSize) -> NSRect) {
    guard let win = focusedWindow() else { return }
    var pos = CGPoint.zero, size = CGSize.zero
    var v: CFTypeRef?
    if AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &v) == .success, let v {
        AXValueGetValue(v as! AXValue, .cgPoint, &pos)
    }
    if AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &v) == .success, let v {
        AXValueGetValue(v as! AXValue, .cgSize, &size)
    }

    // NSScreen 要在主线程读
    let screens = DispatchQueue.main.sync { NSScreen.screens.map { ($0.frame, $0.visibleFrame) } }
    // AX 用左上原点坐标，Cocoa 用左下原点，以主屏高度换算
    let primaryH = screens.first?.0.height ?? 0
    let center = NSPoint(x: pos.x + size.width / 2, y: primaryH - (pos.y + size.height / 2))
    guard let visible = (screens.first(where: { $0.0.contains(center) }) ?? screens.first)?.1 else { return }

    let target = layout(visible, size)
    var newPos = CGPoint(x: target.minX, y: primaryH - target.maxY)
    var newSize = target.size
    // 先移位置再改尺寸，再移一次位置：部分 App 改尺寸时会被屏幕边缘挡住
    for attr in [kAXPositionAttribute, kAXSizeAttribute, kAXPositionAttribute] {
        let value = attr == kAXSizeAttribute
            ? AXValueCreate(.cgSize, &newSize)
            : AXValueCreate(.cgPoint, &newPos)
        if let value { AXUIElementSetAttributeValue(win, attr as CFString, value) }
    }
}

// MARK: - 按键模拟

/// 功能键：位置固定，和键盘布局无关
private let namedKeys: [String: CGKeyCode] = [
    "return": 36, "enter": 36, "tab": 48, "space": 49,
    "delete": 51, "backspace": 51, "escape": 53, "esc": 53, "forwarddelete": 117,
    "left": 123, "right": 124, "down": 125, "up": 126,
    "home": 115, "end": 119, "pageup": 116, "pagedown": 121,
    "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98,
    "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
]

/// 字符键在美式（ANSI）布局下的位置，当前布局查不到时用它
private let ansiKeys: [String: CGKeyCode] = [
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
    "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19,
    "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28,
    "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37, "j": 38,
    "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46, ".": 47,
    "`": 50,
]

/// 按当前键盘布局把字符映射到按键（德语、法语等布局下 [ ] 之类的位置不同）
enum KeyboardLayout {
    private static let lock = NSLock()
    private static var map: [String: CGKeyCode] = [:]

    /// TIS 接口只能在主线程调用；启动时和切换输入法时刷新
    static func refresh() {
        dispatchPrecondition(condition: .onQueue(.main))
        var m: [String: CGKeyCode] = [:]
        if let src = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
           let ptr = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData) {
            let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue()
            CFDataGetBytePtr(data).withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { layout in
                // 0x40 以后是小键盘等，主键盘优先
                for code in 0..<0x40 {
                    var dead: UInt32 = 0
                    var chars = [UniChar](repeating: 0, count: 4)
                    var len = 0
                    let status = UCKeyTranslate(
                        layout, UInt16(code), UInt16(kUCKeyActionDown), 0, UInt32(LMGetKbdType()),
                        OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, chars.count, &len, &chars)
                    guard status == noErr, len > 0 else { continue }
                    let s = String(utf16CodeUnits: chars, count: len).lowercased()
                    if m[s] == nil { m[s] = CGKeyCode(code) }
                }
            }
        }
        lock.lock(); map = m; lock.unlock()
    }

    static func keyCode(for s: String) -> CGKeyCode? {
        if let k = namedKeys[s] { return k }
        lock.lock(); defer { lock.unlock() }
        return map[s] ?? ansiKeys[s]
    }
}

let modifierFlags: [String: CGEventFlags] = [
    "cmd": .maskCommand, "command": .maskCommand,
    "shift": .maskShift,
    "opt": .maskAlternate, "option": .maskAlternate, "alt": .maskAlternate,
    "ctrl": .maskControl, "control": .maskControl,
    "fn": .maskSecondaryFn,
]

func sendKeyCombo(_ combo: String) {
    var flags: CGEventFlags = []
    var code: CGKeyCode?
    for part in combo.lowercased().split(separator: "+", omittingEmptySubsequences: false)
        .map({ $0.trimmingCharacters(in: .whitespaces) }) {
        if let m = modifierFlags[part] { flags.insert(m) }
        else if part.isEmpty { code = KeyboardLayout.keyCode(for: "=") } // "cmd++" 的情况
        else if let k = KeyboardLayout.keyCode(for: part) { code = k }
        else { logger.error("未知按键: \(part, privacy: .public)"); return }
    }
    guard let code else { return }
    // 真实键盘按方向键、Home/End 等时会带上这两个标志，系统快捷键（比如切桌面）依赖它们
    if (115...126).contains(code) { flags.insert(.maskSecondaryFn) }
    if (123...126).contains(code) { flags.insert(.maskNumericPad) }

    let src = CGEventSource(stateID: .hidSystemState)
    for down in [true, false] {
        guard let ev = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: down) else { continue }
        ev.flags = flags
        ev.setIntegerValueField(.eventSourceUserData, value: kSelfMarker)
        ev.post(tap: .cghidEventTap)
    }
}

func runShell(_ cmd: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/zsh")
    p.arguments = ["-lc", cmd]
    do { try p.run() } catch { logger.error("命令执行失败: \(error.localizedDescription, privacy: .public)") }
}
