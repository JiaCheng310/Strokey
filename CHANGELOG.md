# Changelog

## 1.0.2

- Back / forward now work in browsers even when the page captures ⌘[ (e.g. alphaXiv, sites with code editors). Browsers get a simulated mouse side-button click; other apps still get ⌘[ / ⌘] / 后退、前进在浏览器里改为模拟鼠标侧键，网页拦截 ⌘[ 时（如 alphaXiv、带代码编辑器的网站）也能用；其他 App 仍发送 ⌘[ / ⌘]
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
