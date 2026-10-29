// 生成 App 图标：swift icon/make_icon.swift <输出.png>
// 纯代码绘制（不使用 SF Symbols，它的许可不允许用在 App 图标里）

import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

// 底板：macOS 图标网格，824×824，四周留阴影空间
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let plate = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

ctx.saveGState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.shadowBlurRadius = 28
shadow.set()
rgb(0x3A4BD8).setFill()
plate.fill()
ctx.restoreGState()

ctx.saveGState()
plate.addClip()
NSGradient(colors: [rgb(0x4F8DFF), rgb(0x5B4BE6), rgb(0x7A3FD6)],
           atLocations: [0, 0.55, 1], colorSpace: .sRGB)!.draw(in: body, angle: -60)
// 顶部高光
NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
    .draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
ctx.restoreGState()

// 手势轨迹：从鼠标右上方出发，先向右再向下再向右，末端带箭头
let trail = NSBezierPath()
trail.move(to: NSPoint(x: 470, y: 735))
trail.curve(to: NSPoint(x: 700, y: 735), controlPoint1: NSPoint(x: 560, y: 790), controlPoint2: NSPoint(x: 650, y: 790))
trail.curve(to: NSPoint(x: 720, y: 470), controlPoint1: NSPoint(x: 760, y: 670), controlPoint2: NSPoint(x: 700, y: 560))
trail.curve(to: NSPoint(x: 790, y: 340), controlPoint1: NSPoint(x: 735, y: 400), controlPoint2: NSPoint(x: 760, y: 365))
trail.lineWidth = 46
trail.lineCapStyle = .round
trail.lineJoinStyle = .round

ctx.saveGState()
let glow = NSShadow()
glow.shadowColor = rgb(0xFFC93C, 0.55)
glow.shadowBlurRadius = 30
glow.set()
rgb(0xFFC93C).setStroke()
trail.stroke()
ctx.restoreGState()

// 箭头：沿轨迹末端方向
let tip = NSPoint(x: 838, y: 300)
let dir = atan2(tip.y - 340, tip.x - 790)
func at(_ angle: CGFloat, _ len: CGFloat) -> NSPoint {
    NSPoint(x: tip.x - len * cos(dir + angle), y: tip.y - len * sin(dir + angle))
}
let arrow = NSBezierPath()
arrow.move(to: tip)
arrow.line(to: at(0.62, 130))
arrow.line(to: at(-0.62, 130))
arrow.close()
arrow.lineJoinStyle = .round
arrow.lineWidth = 18
rgb(0xFFC93C).setFill()
rgb(0xFFC93C).setStroke()
arrow.fill()
arrow.stroke()

// 鼠标：白色圆角机身，左右键分割线，滚轮
let mouseRect = NSRect(x: 230, y: 230, width: 300, height: 450)
let mouse = NSBezierPath(roundedRect: mouseRect, xRadius: 150, yRadius: 150)
ctx.saveGState()
let ms = NSShadow()
ms.shadowColor = NSColor.black.withAlphaComponent(0.28)
ms.shadowOffset = NSSize(width: 0, height: -12)
ms.shadowBlurRadius = 24
ms.set()
NSColor.white.setFill()
mouse.fill()
ctx.restoreGState()

ctx.saveGState()
mouse.addClip()
NSGradient(colors: [NSColor.white, rgb(0xE6E9F5)])!.draw(in: mouseRect, angle: -90)
ctx.restoreGState()

// 按键区和机身的分割曲线
let splitY = mouseRect.maxY - 205
let splitStart = NSPoint(x: mouseRect.minX, y: splitY)
let splitEnd = NSPoint(x: mouseRect.maxX, y: splitY)
let splitC1 = NSPoint(x: mouseRect.minX + 90, y: splitY - 22)
let splitC2 = NSPoint(x: mouseRect.maxX - 90, y: splitY - 22)

// 右键高亮（按住右键画手势）：右半边、分割曲线以上
ctx.saveGState()
mouse.addClip()
let buttonsArea = NSBezierPath()
buttonsArea.move(to: NSPoint(x: mouseRect.minX, y: mouseRect.maxY + 10))
buttonsArea.line(to: splitStart)
buttonsArea.curve(to: splitEnd, controlPoint1: splitC1, controlPoint2: splitC2)
buttonsArea.line(to: NSPoint(x: mouseRect.maxX, y: mouseRect.maxY + 10))
buttonsArea.close()
buttonsArea.addClip()
rgb(0x5B6CF0, 0.22).setFill()
NSRect(x: mouseRect.midX, y: mouseRect.minY, width: mouseRect.width / 2, height: mouseRect.height).fill()
ctx.restoreGState()

ctx.saveGState()
mouse.addClip()
let split = NSBezierPath()
split.move(to: NSPoint(x: mouseRect.midX, y: mouseRect.maxY))
split.line(to: NSPoint(x: mouseRect.midX, y: splitY - 20))
split.move(to: splitStart)
split.curve(to: splitEnd, controlPoint1: splitC1, controlPoint2: splitC2)
split.lineWidth = 9
split.lineCapStyle = .round
rgb(0xB9BFD6).setStroke()
split.stroke()
ctx.restoreGState()

let wheel = NSBezierPath(roundedRect: NSRect(x: mouseRect.midX - 20, y: mouseRect.maxY - 145, width: 40, height: 80),
                         xRadius: 20, yRadius: 20)
rgb(0x5B4BE6).setFill()
wheel.fill()

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
