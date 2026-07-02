# TermPet

TermPet 是一个原生 macOS 终端宠物。它会在终端处于前台时显示在桌面上，跟随鼠标轻微移动，并根据终端命令结果、系统状态和提醒事件做出反馈。

项目当前是 MVP 阶段，重点放在本地可运行、隐私友好和轻量交互上。界面使用 AppKit + SwiftUI 实现，核心逻辑使用纯 Swift 编写，工程通过 SwiftPM 构建。

## 功能

- 透明置顶宠物窗口，仅在终端类应用处于前台时显示
- 鼠标追随、漂浮和状态反馈动画
- 菜单栏入口，可控制监听、显示状态、设置和退出
- 信息面板，展示系统状态、最近终端事件和提醒
- zsh hook 监听命令开始、结束、退出码和耗时
- 系统资源监控，包括 CPU、内存、磁盘和电池
- 三种回复性格：温柔、毒舌、技术型
- 支持本地贴纸图片配置
- 支持 OpenAI-compatible 和 Ollama 配置，未配置或失败时回退到本地规则回复
- 对命令中的 password、token、Authorization Bearer、常见 API key 做脱敏处理

## 支持的终端

TermPet 会在以下终端类应用处于前台时显示：

- Terminal
- iTerm2
- Ghostty
- Warp
- WezTerm
- Alacritty
- kitty

切换到浏览器、Finder、编辑器等非终端应用时，宠物会自动隐藏。

## 环境要求

- macOS 14 或更高版本
- Swift 6.3 或兼容版本
- zsh，用于终端事件 hook

## 运行

```bash
git clone https://github.com/Elevaene/TermPet.git
cd TermPet
swift run TermPet
```

启动后会出现透明宠物窗口和菜单栏 `🐾`。默认快捷键：

| 操作 | 作用 |
|------|------|
| `⌥⌘P` | 显示或隐藏宠物 |
| 单击宠物 | 打开信息面板 |
| 菜单栏 `🐾` | 暂停监听、显示/隐藏、设置、退出 |

## 终端事件监听

安装 zsh hook：

```bash
Scripts/install-zsh-hook.sh
```

安装后打开一个新的终端窗口，TermPet 会读取命令事件并根据结果切换状态：

- 命令开始：进入工作状态
- 命令成功：显示成功反馈
- 命令失败：根据性格给出提示或吐槽
- 同一命令连续失败：提示停止重复尝试
- 长时间运行：进入等待状态

卸载 zsh hook：

```bash
Scripts/uninstall-zsh-hook.sh
```

事件日志默认写入：

```text
~/Library/Application Support/TermPet/events.jsonl
```

## 设置

菜单栏设置面板支持配置：

- 性格、宠物大小、免打扰和发言间隔
- AI provider、API URL、API Key 和模型名
- Ollama URL 和模型名
- 自定义宠物贴纸
- 暂停或恢复终端监听

AI 回复只会使用脱敏后的命令、退出码、耗时等简要上下文。TermPet 不会自动执行命令。

## 开发

运行逻辑测试：

```bash
swift run TermPetLogicTests
```

构建项目：

```bash
swift build
```

项目结构：

```text
Sources/TermPet        macOS App、窗口、菜单栏和 SwiftUI 视图
Sources/TermPetCore    事件模型、隐私过滤、回复逻辑和系统监控规则
Scripts                zsh hook 安装与卸载脚本
Tests                  纯逻辑测试
```

## 隐私

TermPet 不记录命令输出。shell hook 只写入命令开始、命令结束、退出码和耗时等事件字段。

命令文本会在进入应用前经过脱敏处理，应用侧也会再次过滤常见敏感字段，包括 password、token、Authorization Bearer 和常见 API key。
