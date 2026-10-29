// 手势识别：右键 / 中键 / 侧键拖动手势、右键 + 滚轮、摇杆手势
// 手势由方向序列组成：L 左、R 右、U 上、D 下，例如 "DR" = 先下后右。

import Cocoa

final class GestureEngine {
    var config = loadConfig()
    var enabled = true
    let overlay = Overlay()
    let scroller = SmoothScroller()

    /// 画完手势后停住不动超过这个时间，松开就取消
    private let cancelDelay = 0.8

    private var button: Int?          // 正在追踪的按键：1 右键，2 中键，3/4 侧键
    private var start = CGPoint.zero
    private var anchor = CGPoint.zero
    private var moved = false
    private var used = false          // 已经触发过滚轮或摇杆手势，松开时不再执行
    private var cancelled = false
    private var cancelTimer: Timer?
    private var strokes: [Character] = []
    private var bundleID: String?
    private var wheelAccum = 0.0

    private var leftHeld = false
    private var swallowLeftUp = false
    private var swallowRightUp = false

    private let arrows: [Character: String] = ["L": "←", "R": "→", "U": "↑", "D": "↓"]

    /// 返回 nil 表示吞掉事件
    func handle(type: CGEventType, event: CGEvent) -> CGEvent? {
        if event.getIntegerValueField(.eventSourceUserData) == kSelfMarker { return event }

        // 自检：松开事件可能丢失（系统临时停用 event tap、安全输入等），
        // 这时记录的状态会"卡住"，导致左键、滚轮被一直吞掉。按下类事件到来时，用硬件状态校正一下。
        if type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown || type == .scrollWheel {
            if let b = button, !isPhysicallyDown(b) {
                logger.notice("按键 \(b) 的松开事件丢失，重置手势状态")
                reset()
            }
            if leftHeld && !isPhysicallyDown(0) { leftHeld = false }
        }

        switch type {
        case .leftMouseDown:
            if button == 1, let a = config.rocker.rightThenLeft {
                used = true
                swallowLeftUp = true
                showLabel("\(L("右键+左键", "Right+Left"))  \(a.label)", at: event.location)
                run(a)
                return nil
            }
            leftHeld = true
            return event

        case .leftMouseUp:
            leftHeld = false
            if swallowLeftUp { swallowLeftUp = false; return nil }
            return event

        case .rightMouseDown:
            if enabled, leftHeld, button == nil, !isExcluded(), let a = config.rocker.leftThenRight {
                swallowRightUp = true
                run(a)
                return nil
            }
            return begin(1, event)

        case .rightMouseDragged:
            return button == 1 ? drag(event) : event

        case .rightMouseUp:
            if swallowRightUp { swallowRightUp = false; return nil }
            return button == 1 ? end() : event

        case .otherMouseDown:
            let b = buttonNumber(event)
            guard let bc = config.buttons["\(b)"], bc.click != nil || !(bc.drag ?? [:]).isEmpty else { return event }
            return begin(b, event)

        case .otherMouseDragged:
            return button == buttonNumber(event) ? drag(event) : event

        case .otherMouseUp:
            return button == buttonNumber(event) ? end() : event

        case .scrollWheel:
            if button == 1, config.wheelGesture.up != nil || config.wheelGesture.down != nil {
                return wheel(event)
            }
            return scroller.handle(event, cfg: config.scroll)

        default:
            return event
        }
    }

    // MARK: - 拖动手势

    private func begin(_ b: Int, _ event: CGEvent) -> CGEvent? {
        guard enabled, button == nil else { return event }
        bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if isExcluded() { return event }
        button = b
        moved = false
        used = false
        cancelled = false
        strokes = []
        wheelAccum = 0
        start = event.location
        anchor = start
        return nil
    }

    private func drag(_ event: CGEvent) -> CGEvent? {
        if used { return nil }
        let p = event.location
        if !moved && hypot(p.x - start.x, p.y - start.y) > 6 {
            moved = true
            if config.showTrail { overlay.begin(); overlay.add(start, label: nil) }
        }
        let dx = p.x - anchor.x, dy = p.y - anchor.y
        if hypot(dx, dy) >= config.minStroke {
            let dir: Character = abs(dx) > abs(dy) ? (dx > 0 ? "R" : "L") : (dy > 0 ? "D" : "U")
            if strokes.last != dir { strokes.append(dir) }
            anchor = p
        }
        if moved && config.showTrail { overlay.add(p, label: currentLabel()) }

        // 停住不动一会儿就取消，再动起来就恢复
        cancelled = false
        cancelTimer?.invalidate()
        cancelTimer = Timer.scheduledTimer(withTimeInterval: cancelDelay, repeats: false) { [weak self] _ in
            guard let self, self.button != nil, !self.strokes.isEmpty else { return }
            self.cancelled = true
            self.overlay.setLabel(L("✕ 已取消", "✕ Cancelled"))
        }
        return nil
    }

    private func end() -> CGEvent? {
        guard let b = button else { return nil }
        button = nil
        cancelTimer?.invalidate()
        overlay.end()
        if used || cancelled { return nil }

        if strokes.isEmpty {
            if b != 1, let a = config.buttons["\(b)"]?.click { run(a) }
            else { replayClick(b, at: start) }
        } else if let a = lookup(b) {
            run(a)
        }
        return nil
    }

    // MARK: - 右键 + 滚轮

    private func wheel(_ e: CGEvent) -> CGEvent? {
        used = true
        cancelTimer?.invalidate()
        // 普通滚轮一格一个事件；触控板 / 妙控鼠标按 40 像素算一格
        let continuous = e.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        wheelAccum += continuous
            ? e.getDoubleValueField(.scrollWheelEventPointDeltaAxis1) / 40
            : Double(e.getIntegerValueField(.scrollWheelEventDeltaAxis1))
        while abs(wheelAccum) >= 1 {
            let up = wheelAccum > 0
            wheelAccum += up ? -1 : 1
            if let a = up ? config.wheelGesture.up : config.wheelGesture.down {
                showLabel("\(L("滚轮", "Wheel")) \(up ? "↑" : "↓")  \(a.label)", at: e.location)
                run(a)
            }
        }
        return nil
    }

    // MARK: - 工具

    /// 清空所有追踪状态。event tap 被系统停用后恢复时也会调用
    func reset() {
        button = nil
        cancelTimer?.invalidate()
        overlay.end()
        leftHeld = false
        swallowLeftUp = false
        swallowRightUp = false
    }

    private func isPhysicallyDown(_ b: Int) -> Bool {
        guard let mb = CGMouseButton(rawValue: UInt32(b)) else { return false }
        return CGEventSource.buttonState(.hidSystemState, button: mb)
    }

    private func buttonNumber(_ e: CGEvent) -> Int {
        Int(e.getIntegerValueField(.mouseEventButtonNumber))
    }

    private func isExcluded() -> Bool {
        let bid = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        return bid.map(config.excludeApps.contains) ?? false
    }

    private func lookup(_ b: Int) -> Action? {
        let key = String(strokes)
        if b == 1 {
            if let bid = bundleID, let a = config.apps[bid]?[key] { return a }
            return config.global[key]
        }
        return config.buttons["\(b)"]?.drag?[key]
    }

    private func currentLabel() -> String? {
        guard let b = button, !strokes.isEmpty else { return nil }
        let arrowStr = strokes.compactMap { arrows[$0] }.joined(separator: " ")
        if let a = lookup(b) { return "\(arrowStr)  \(a.label)" }
        return arrowStr
    }

    private func showLabel(_ text: String, at p: CGPoint) {
        guard config.showTrail else { return }
        if !overlay.visible { overlay.begin() }
        overlay.add(p, label: text)
    }

    /// 动作在后台队列执行（见 perform），不阻塞 event tap 回调
    private func run(_ a: Action) {
        perform(a)
    }

    /// 没画出手势：把被吞掉的点击原样补发，保证右键菜单、中键点击正常
    private func replayClick(_ b: Int, at p: CGPoint) {
        postClick(button: b, at: p)
    }
}
