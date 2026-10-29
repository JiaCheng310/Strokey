<p align="center">
  <img src="assets/icon.png" width="128" alt="Strokey 图标">
</p>

<h1 align="center">Strokey</h1>

<p align="center">
  macOS 鼠标手势、侧键映射和平滑滚动。<br>
  适用于任何鼠标，不依赖厂商驱动。
</p>

<p align="center">
  <a href="README.md">English</a> · <b>简体中文</b>
</p>

---

## 功能

| 功能 | 用法 | 默认动作 |
|---|---|---|
| **右键手势** | 按住右键拖动画方向，松开执行 | ← 后退、→ 前进、↓→ 关闭标签页……（见下表） |
| **中键手势** | 按住中键拖动 | ↑ 调度中心、↓ 当前 App 的所有窗口、← / → 切换桌面 |
| **侧键** | 点击鼠标侧键 | 后退 / 前进，Finder、Safari 里也能用 |
| **右键 + 滚轮** | 按住右键滚动滚轮 | 上一个 / 下一个标签页 |
| **摇杆手势** | 按住右键点左键 / 按住左键点右键 | 后退 / 前进 |
| **平滑滚动** | 自动生效，只作用于普通鼠标滚轮 | ⇧ 横向滚动，⌥ 精细滚动 |
| **取消手势** | 画完后停住 0.8 秒再松开 | — |

只点一下右键或中键、不拖动的话，行为和平时一样（右键菜单、中键在新标签页打开链接）。

画手势时会显示轨迹，旁边提示松开后会执行什么。

### 默认右键手势

| 手势 | 动作 | 手势 | 动作 |
|---|---|---|---|
| ← | 后退 | ↑ ↓ | 刷新 |
| → | 前进 | ↑ ← / ↑ → | 上一个 / 下一个标签页 |
| ↑ | 回到顶部 | → ↓ | 最小化窗口 |
| ↓ | 到底部 | → ↑ | 窗口最大化 |
| ↓ → | 关闭标签页 | ← ↓ → | 窗口放左半屏 |
| ↓ ← | 恢复关闭的标签页 | → ↓ ← | 窗口放右半屏 |

## 安装

需要 macOS 13 Ventura 或更新版本，Apple 芯片和 Intel 芯片的 Mac 都原生支持。

### 方式一：一行命令安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/JiaCheng310/Strokey/main/scripts/install.sh | zsh
```

会自动下载最新版本，装到「应用程序」文件夹并启动。

### 方式二：手动下载

1. 从 [Releases](https://github.com/JiaCheng310/Strokey/releases) 下载 `Strokey-x.y.z.zip` 并解压。
2. 把 `Strokey.app` 拖进「应用程序」文件夹。
3. 打开它。Strokey 没有经过 Apple 公证（公证需要付费的开发者账号），所以第一次打开会被系统拦截：
   - **macOS 15 Sequoia 及以上**：先尝试打开一次，然后去 **系统设置 → 隐私与安全性**，往下滚，点 **仍要打开**。
   - **macOS 13 / 14**：右键点 `Strokey.app` → **打开** → **打开**。
   - 或者在终端里运行：
     ```bash
     xattr -dr com.apple.quarantine /Applications/Strokey.app
     ```

### 方式三：从源码编译

需要 Xcode 或命令行工具（`xcode-select --install`）。

```bash
git clone https://github.com/JiaCheng310/Strokey.git
cd Strokey
make install
```

### 授予辅助功能权限

Strokey 需要辅助功能权限才能接收鼠标事件、发送快捷键。首次启动时：

1. 系统会弹出权限请求。打开 **系统设置 → 隐私与安全性 → 辅助功能**。
2. 打开 **Strokey** 的开关。
3. 两秒内菜单栏图标会从 ⚠️ 变成 ✋，不用重启。

> **更新版本后**，因为没有用开发者证书签名，系统可能会把新版本当成另一个 App。如果手势失效了，在辅助功能列表里选中 Strokey 点 **−** 删掉，再重新添加一次。

## 使用

点菜单栏的 ✋ 图标可以：

- 开关鼠标手势和平滑滚动
- 设置开机启动
- 打开或重新加载配置文件
- 检查更新

## 配置

配置文件在 `~/.config/strokey/config.json`，首次启动时自动生成。改完后在菜单里点 **重新加载配置**。

```jsonc
{
  "minStroke": 30,            // 一笔的最小长度（像素），越小越灵敏
  "showTrail": true,          // 显示轨迹和动作提示
  "excludeApps": ["com.valvesoftware.steam"],   // 这些 App 在前台时不拦截鼠标按键（比如游戏）

  // 右键手势。L 左、R 右、U 上、D 下
  "global": {
    "DR": { "name": "关闭标签页", "key": "cmd+w" },
    "LU": { "name": "打开终端", "shell": "open -a Terminal" },
    "RU": { "name": "窗口最大化", "action": "windowMaximize" }
  },

  // 按 App 覆盖右键手势（bundle id 可以用 osascript -e 'id of app "Safari"' 查）
  "apps": {
    "com.apple.finder": { "U": { "name": "上级目录", "key": "cmd+up" } }
  },

  // "2" 中键，"3" / "4" 侧键。click = 单击，drag = 按住拖动的手势
  "buttons": {
    "2": { "drag": { "U": { "action": "missionControl" } } },
    "3": { "click": { "name": "后退", "key": "cmd+[" } },
    "4": { "click": { "name": "前进", "key": "cmd+]" } }
  },

  "wheelGesture": { "up": { "key": "ctrl+shift+tab" }, "down": { "key": "ctrl+tab" } },
  "rocker": { "rightThenLeft": { "key": "cmd+[" }, "leftThenRight": { "key": "cmd+]" } },

  "scroll": {
    "enabled": true,
    "reverse": false,         // 只反转鼠标滚轮，触控板不受影响
    "speed": 1.0,
    "smoothness": 0.25,       // 越大越顺滑，越小越跟手
    "acceleration": true
  }
}
```

### 动作

每个动作支持以下写法，可以组合使用：

- `"key"`：快捷键，例如 `cmd+shift+t`、`ctrl+left`、`f11`。修饰键：`cmd` `shift` `opt` `ctrl` `fn`。会按当前键盘布局识别按键。
- `"shell"`：shell 命令，例如 `open -a Safari`。
- `"action"`：内置动作：

| 内置动作 | 说明 |
|---|---|
| `missionControl` / `appExpose` / `showDesktop` / `launchpad` | 调度中心 / 当前 App 的所有窗口 / 显示桌面 / 启动台 |
| `spaceLeft` / `spaceRight` | 切换到左边 / 右边的桌面（到头时会提示） |
| `windowLeft` / `windowRight` / `windowMaximize` / `windowCenter` / `windowMinimize` | 窗口左半屏 / 右半屏 / 最大化 / 居中 / 最小化 |
| `volumeUp` / `volumeDown` / `mute` | 音量 |
| `playPause` / `nextTrack` / `previousTrack` | 媒体控制 |
| `brightnessUp` / `brightnessDown` | 屏幕亮度 |

`name` 是可选的，用来在画手势时显示。

## 隐私

Strokey 会拦截鼠标事件，下面说清楚它具体做了什么：

- **只监听鼠标**：只监听鼠标按键、拖动和滚轮事件，**不监听键盘**。只有在你配置的手势需要时，才会**发送**按键。
- **不联网**：Strokey 从不连接网络。「检查更新」只是在浏览器里打开 Releases 页面。
- **不收集数据**：不记录、不存储、不上传任何内容。唯一会写的文件是你的配置文件。
- **日志只在本机**：为了方便排查问题，每次触发的动作名称会写进本机的 macOS 系统日志。
- **完全开源**：所有代码都在这个仓库里，可以自己阅读，也可以自己编译。

## 常见问题

| 问题 | 解决办法 |
|---|---|
| 菜单栏图标是 ⚠️ | 缺少辅助功能权限。点图标 → 打开设置，打开 Strokey 的开关。 |
| 更新后没反应了 | 在辅助功能列表里选中 Strokey 点 **−** 删掉，再重新添加。 |
| 切换桌面没反应 | 确认 **系统设置 → 键盘 → 键盘快捷键 → 调度中心 → 向左 / 向右移动一个空间** 是开着的。 |
| 游戏或某个 App 需要用右键拖动 | 把它的 bundle id 加进 `excludeApps`。 |
| 鼠标好像卡住了 | 按 ⌘⌥⎋ 强制退出 Strokey，然后带上下面的日志 [提交 issue](https://github.com/JiaCheng310/Strokey/issues)。 |

查看日志：

```bash
log show --last 10m --predicate 'subsystem == "io.github.jiacheng310.strokey"'
```

## 卸载

1. 点菜单栏图标 → **退出**。
2. 删除 `/Applications/Strokey.app`。
3. 在 **系统设置 → 隐私与安全性 → 辅助功能** 里删掉 Strokey（如果开了开机启动，也去 **登录项** 里删掉）。
4. 如果不需要配置了，可以删除：`rm -rf ~/.config/strokey`。

## 开发

```bash
make build     # 编译 build/Strokey.app（通用二进制）
make run       # 编译后直接运行，不安装
make install   # 编译、装到「应用程序」并启动
make dist      # 在 dist/ 里生成发布用的 zip
make icon      # 用 scripts/make_icon.swift 重新生成图标
```

| 文件 | 作用 |
|---|---|
| `Sources/Strokey/main.swift` | event tap 安装、菜单栏 |
| `Sources/Strokey/Engine.swift` | 手势识别（拖动、滚轮、摇杆） |
| `Sources/Strokey/SmoothScroll.swift` | 平滑滚动 |
| `Sources/Strokey/Actions.swift` | 快捷键、内置动作、窗口管理 |
| `Sources/Strokey/Overlay.swift` | 轨迹和提示浮层 |
| `Sources/Strokey/Config.swift` | 配置读写、界面文字 |

发布新版本只要推送一个标签，GitHub Actions 会自动编译并上传 zip：

```bash
git tag v1.0.0 && git push origin v1.0.0
```

部分内置动作（调度中心、判断桌面是否到头）用到了 macOS 的私有接口。不在 Mac App Store 上架的 App 用这些接口没有问题，但以后的 macOS 版本可能会让它们失效。接口不可用时，Strokey 会自动退回普通方式。

## 开源协议

[MIT](LICENSE)
