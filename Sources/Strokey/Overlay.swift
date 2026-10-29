// 手势轨迹和动作提示浮层

import Cocoa

final class TrailView: NSView {
    var points: [NSPoint] = []
    var label: String?

    override func draw(_ dirtyRect: NSRect) {
        if points.count > 1 {
            let path = NSBezierPath()
            path.lineWidth = 4
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: points[0])
            for p in points.dropFirst() { path.line(to: p) }
            NSColor.systemBlue.withAlphaComponent(0.8).setStroke()
            path.stroke()
        }

        if let label, let last = points.last {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: NSColor.white,
            ]
            let str = NSAttributedString(string: label, attributes: attrs)
            let size = str.size()
            let box = NSRect(x: last.x + 16, y: last.y - size.height - 20,
                             width: size.width + 20, height: size.height + 10)
            NSColor.black.withAlphaComponent(0.75).setFill()
            NSBezierPath(roundedRect: box, xRadius: 8, yRadius: 8).fill()
            str.draw(at: NSPoint(x: box.minX + 10, y: box.minY + 5))
        }
    }
}

final class Overlay {
    let window: NSWindow
    let view = TrailView()
    private(set) var visible = false
    private var pendingHide: DispatchWorkItem?

    init() {
        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView = view
    }

    func begin() {
        pendingHide?.cancel()
        // 覆盖所有显示器
        let frame = NSScreen.screens.map(\.frame).reduce(NSRect.null) { $0.union($1) }
        window.setFrame(frame, display: false)
        view.points = []
        view.label = nil
        window.orderFrontRegardless()
        visible = true
    }

    /// CG 坐标（左上原点）→ 窗口内坐标
    func add(_ cg: CGPoint, label: String?) {
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        let p = NSPoint(x: cg.x - window.frame.minX, y: primaryH - cg.y - window.frame.minY)
        view.points.append(p)
        view.label = label
        view.needsDisplay = true
    }

    func setLabel(_ label: String?) {
        view.label = label
        view.needsDisplay = true
    }

    /// 在鼠标旁短暂显示一条提示（主线程调用）
    func flash(_ text: String) {
        begin()
        add(CGEvent(source: nil)?.location ?? .zero, label: text)
        let hide = DispatchWorkItem { [weak self] in self?.end() }
        pendingHide = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: hide)
    }

    func end() {
        window.orderOut(nil)
        view.points = []
        visible = false
    }
}
