// Strokey — macOS 鼠标手势、侧键映射和平滑滚动
// 入口：event tap 安装和菜单栏

import Cocoa
import ApplicationServices
import ServiceManagement
import Carbon

let engine = GestureEngine()
var eventTap: CFMachPort?

func installTap() -> Bool {
    let types: [CGEventType] = [
        .leftMouseDown, .leftMouseUp,
        .rightMouseDown, .rightMouseDragged, .rightMouseUp,
        .otherMouseDown, .otherMouseDragged, .otherMouseUp,
        .scrollWheel,
    ]
    let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
    guard let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
        eventsOfInterest: mask,
        callback: { _, type, event, _ in
            // 系统会在回调超时或安全输入（输密码）时停用 tap，期间的事件我们收不到
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                logger.notice("event tap 被系统停用（\(type == .tapDisabledByTimeout ? "超时" : "用户输入")），重新启用")
                engine.reset()
                if let t = eventTap { CGEvent.tapEnable(tap: t, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            guard let out = engine.handle(type: type, event: event) else { return nil }
            return Unmanaged.passUnretained(out)
        },
        userInfo: nil
    ) else { return false }
    eventTap = tap
    let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    return true
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var permissionItem: NSMenuItem!
    var gestureItem: NSMenuItem!
    var scrollItem: NSMenuItem!
    var loginItem: NSMenuItem!

    func applicationDidFinishLaunching(_ n: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()

        permissionItem = item(L("⚠️ 需要辅助功能权限，点此打开设置", "⚠️ Accessibility permission needed — Open Settings"), #selector(openPrivacySettings))
        menu.addItem(permissionItem)
        gestureItem = item(L("鼠标手势", "Mouse Gestures"), #selector(toggleGestures))
        menu.addItem(gestureItem)
        scrollItem = item(L("平滑滚动", "Smooth Scrolling"), #selector(toggleScroll))
        menu.addItem(scrollItem)
        loginItem = item(L("开机启动", "Launch at Login"), #selector(toggleLogin))
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(item(L("重新加载配置", "Reload Config"), #selector(reload), key: "r"))
        menu.addItem(item(L("打开配置文件", "Open Config File"), #selector(openConfig), key: ","))
        menu.addItem(.separator())
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        menu.addItem(item("Strokey \(version) · \(L("检查更新", "Check for Updates"))", #selector(openHomepage)))
        menu.addItem(NSMenuItem(title: L("退出", "Quit"), action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        refreshMenu()
        startWhenTrusted()

        // 快捷键按当前键盘布局查找按键，切换输入法时更新
        KeyboardLayout.refresh()
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main) { _ in KeyboardLayout.refresh() }

        // 睡眠唤醒后确认 tap 仍然启用
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            engine.reset()
            if let t = eventTap, !CGEvent.tapIsEnabled(tap: t) {
                logger.notice("唤醒后重新启用 event tap")
                CGEvent.tapEnable(tap: t, enable: true)
            }
        }
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    private func refreshMenu() {
        let trusted = eventTap != nil
        statusItem.button?.image = NSImage(
            systemSymbolName: trusted ? "hand.draw" : "exclamationmark.triangle",
            accessibilityDescription: "Strokey")
        permissionItem.isHidden = trusted
        gestureItem.state = engine.enabled ? .on : .off
        scrollItem.state = engine.config.scroll.enabled ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    func startWhenTrusted() {
        // 第一次运行会弹系统提示，并把 App 加进「辅助功能」列表
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(opts), installTap() {
            logger.notice("已获得辅助功能权限，event tap 已启用")
            refreshMenu()
            return
        }
        logger.notice("等待辅助功能权限")
        // 授权后自动生效，不用重启
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
            if AXIsProcessTrusted(), installTap() {
                logger.notice("已获得辅助功能权限，event tap 已启用")
                t.invalidate()
                self?.refreshMenu()
            }
        }
    }

    @objc func openPrivacySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc func toggleGestures() {
        engine.enabled.toggle()
        refreshMenu()
    }

    @objc func toggleScroll() {
        engine.config.scroll.enabled.toggle()
        saveConfig(engine.config)
        refreshMenu()
    }

    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            let alert = NSAlert()
            alert.messageText = L("设置开机启动失败", "Couldn't change Launch at Login")
            alert.informativeText = "\(error.localizedDescription)\n" + L(
                "可以手动在「系统设置 → 通用 → 登录项」里添加 Strokey。",
                "You can add Strokey manually in System Settings → General → Login Items.")
            if #available(macOS 14, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
            alert.runModal()
        }
        refreshMenu()
    }

    @objc func reload() {
        engine.config = loadConfig()
        refreshMenu()
    }

    @objc func openConfig() { NSWorkspace.shared.open(configURL) }

    @objc func openHomepage() { NSWorkspace.shared.open(URL(string: "https://github.com/JiaCheng310/Strokey/releases")!) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
