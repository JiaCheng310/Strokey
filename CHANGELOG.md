# Changelog

## 1.0.4

- Back / forward that pages can't block now works in more browsers. Apps without an AppleScript back command (Safari, Firefox, Arc, Zen, Orion, DuckDuckGo, Opera, Finder…) get their own Back / Forward menu item pressed, found by its ⌘[ / ⌘] shortcut so it works in any system language. No extra permission needed / 网页拦不住的后退、前进支持更多浏览器。没有 AppleScript 后退命令的 App（Safari、Firefox、Arc、Zen、Orion、DuckDuckGo、Opera、Finder 等）改为点击它们自己的「后退 / 前进」菜单项，按 ⌘[ / ⌘] 快捷键查找，和系统语言无关，不需要额外权限
- More Chromium variants use AppleScript (Chrome for Testing, Edge Canary, Brave Beta / Nightly, Vivaldi Snapshot) / 更多 Chromium 系浏览器版本使用 AppleScript
- Code editors (VS Code, Cursor, Windsurf, Zed) use the side button, since ⌘[ means "outdent" there / 代码编辑器（VS Code、Cursor、Windsurf、Zed）使用侧键，因为 ⌘[ 在编辑器里是"减少缩进"

## 1.0.3

- Back / forward can no longer be blocked by web pages. Pages can swallow ⌘[ (code editors such as CodeMirror on alphaXiv) and even cancel the mouse side buttons (PDF viewers). In Chrome, Edge, Brave, Vivaldi and Chromium, Strokey now uses the browser's own back command via AppleScript, same as clicking the toolbar button. macOS asks once for permission to control the browser / 后退、前进不会再被网页拦截。网页能吞掉 ⌘[（如 alphaXiv 上的 CodeMirror 编辑器），甚至取消鼠标侧键（PDF 阅读器）。现在 Chrome、Edge、Brave、Vivaldi、Chromium 通过 AppleScript 调用浏览器自己的后退命令，和点工具栏按钮一样；首次使用时系统会询问是否允许控制浏览器
- Arc, Firefox, VS Code, Cursor: simulated side-button click. Other apps (Safari, Finder…): ⌘[ / ⌘] / Arc、Firefox、VS Code、Cursor 模拟侧键；其他 App（Safari、Finder 等）发送 ⌘[ / ⌘]
- New built-in actions `back` / `forward` / 新增内置动作 `back` / `forward`
- Logs now include the frontmost app / 日志里记录当时的前台 App

## 1.0.1

- Scroll-to-top / bottom gestures (↑ / ↓) now scroll the area under the pointer instead of sending ⌘↑ / ⌘↓, so they also work in web-based apps and while a text field has focus / 「回到顶部 / 到底部」改为滚动鼠标所在区域，不再发送 ⌘↑ / ⌘↓，在网页类 App 和输入框有焦点时也能用
- New built-in actions `scrollTop` / `scrollBottom` / 新增内置动作 `scrollTop` / `scrollBottom`

## 1.0.0

First public release. / 首个公开版本。

- Right, middle and side-button gestures with trail overlay / 右键、中键、侧键手势，带轨迹提示
- Wheel and rocker gestures / 右键 + 滚轮、摇杆手势
- Smooth scrolling for regular mouse wheels / 普通鼠标滚轮平滑滚动
- Built-in actions: Mission Control, desktops, window tiling, media keys / 内置动作：调度中心、切换桌面、窗口管理、媒体键
- Per-app gestures and excluded apps / 按 App 设置手势、排除指定 App
- English and Chinese UI / 中英文界面
