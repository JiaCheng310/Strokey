// 平滑滚动：把普通鼠标滚轮一格一格的跳动，换成带缓动的像素级滚动
// 触控板、妙控鼠标本来就是平滑的，直接放行。

import Cocoa

final class SmoothScroller {
    private var remainingX = 0.0, remainingY = 0.0   // 还没滚完的距离
    private var fracX = 0.0, fracY = 0.0             // 不足 1 像素的余数
    private var flags: CGEventFlags = []
    private var timer: Timer?
    private var lastTick = 0.0
    private var lastNotch = 0.0
    private var streak = 0
    private var smoothness = 0.25

    func handle(_ e: CGEvent, cfg: ScrollConfig) -> CGEvent? {
        guard cfg.enabled else { return e }
        if e.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 { return e }

        var f = e.flags
        // ⌘ / ⌃ + 滚轮通常是缩放，交给系统和 App 原样处理
        if f.contains(.maskCommand) || f.contains(.maskControl) { return e }

        var dy = Double(e.getIntegerValueField(.scrollWheelEventDeltaAxis1))
        var dx = Double(e.getIntegerValueField(.scrollWheelEventDeltaAxis2))
        if dx == 0 && dy == 0 { return e }
        if cfg.reverse { dx = -dx; dy = -dy }

        // ⇧ + 滚轮 = 横向滚动（发出的是精确滚动事件，App 不会再帮我们转换）
        if f.contains(.maskShift) && dx == 0 { dx = dy; dy = 0; f.remove(.maskShift) }

        var step = 50 * cfg.speed
        // ⌥ + 滚轮 = 精细滚动
        if f.contains(.maskAlternate) { step *= 0.25; f.remove(.maskAlternate) }

        let now = CACurrentMediaTime()
        if cfg.acceleration {
            streak = now - lastNotch < 0.12 ? min(streak + 1, 12) : 0
            step *= 1 + Double(streak) * 0.25
        }
        lastNotch = now

        // 反向滚动时，丢掉还没滚完的部分，避免"拉扯感"
        if remainingY * dy < 0 { remainingY = 0 }
        if remainingX * dx < 0 { remainingX = 0 }
        remainingY += dy * step
        remainingX += dx * step
        flags = f
        smoothness = max(cfg.smoothness, 0.01)

        if timer == nil {
            lastTick = now
            let t = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in self?.tick() }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
        return nil
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = now - lastTick
        lastTick = now

        // 指数缓动：每帧滚掉剩余距离的一部分，开头快、结尾慢
        let k = 1 - exp(-dt / (smoothness / 4))
        let moveY = remainingY * k, moveX = remainingX * k
        remainingY -= moveY
        remainingX -= moveX
        fracY += moveY
        fracX += moveX
        let iy = Int32(fracY.rounded(.towardZero)), ix = Int32(fracX.rounded(.towardZero))
        fracY -= Double(iy)
        fracX -= Double(ix)

        if iy != 0 || ix != 0,
           let ev = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: iy, wheel2: ix, wheel3: 0) {
            ev.flags = flags
            ev.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
            ev.setIntegerValueField(.eventSourceUserData, value: kSelfMarker)
            ev.post(tap: .cghidEventTap)
        }

        if abs(remainingY) < 0.5 && abs(remainingX) < 0.5 {
            timer?.invalidate()
            timer = nil
            remainingX = 0; remainingY = 0; fracX = 0; fracY = 0
        }
    }
}
