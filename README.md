# TermPet

TermPet 是一个原生 macOS 终端宠物 MVP，使用 SwiftPM、AppKit、SwiftUI 和纯 Swift 逻辑实现。

## 运行

```bash
swift run TermPet
```

启动后会创建一个透明置顶宠物窗口和菜单栏 `🐾`。宠物只会在前台应用是终端类 App 时展示，目前识别：

- Terminal
- iTerm2
- Ghostty
- Warp
- WezTerm
- Alacritty
- kitty

切到浏览器、Codex、Finder 等非终端应用时，宠物会自动隐藏，避免占屏幕空间。

## 交互

| 操作 | 作用 |
|------|------|
| `⌥⌘P` | 显示/隐藏宠物 |
| 单击宠物 | 打开信息面板 |
| 菜单栏 `🐾` | 暂停监听、显示/隐藏、设置、退出 |

宠物在终端前台时会平滑跟随鼠标位置，并根据鼠标方向轻微漂浮、倾斜。默认使用内置贴纸图，也可以在设置里上传自己的 PNG/JPG/HEIC/TIFF 图片。

## 信息面板

单击宠物打开信息面板：

- 系统：CPU、内存、磁盘、电池状态
- 事件：最近终端命令事件
- 提醒：快捷提醒和自定义提醒

关闭面板时窗口由 controller 持有并统一释放，避免 AppKit/SwiftUI 生命周期导致的崩溃。

## 设置

菜单栏 `🐾` -> 设置：

- 性格、宠物大小、免打扰、发言间隔
- AI provider、API URL、API Key、模型名
- Ollama URL 和模型名
- 自定义宠物贴纸 / 恢复默认贴纸
- 暂停监听

AI 未配置或请求失败时会自动回退到本地规则回复。

## 终端事件 Hook

安装 zsh hook：

```bash
Scripts/install-zsh-hook.sh
```

打开新终端后运行 `true`、`false`、重复 `false`、`sleep 35` 等命令，宠物会根据命令开始、成功、失败、重复失败、长耗时做出反应。

卸载 hook：

```bash
Scripts/uninstall-zsh-hook.sh
```

事件写入：

```text
~/Library/Application Support/TermPet/events.jsonl
```

hook 和 App 都会对 password、token、Authorization Bearer、常见 API key 做脱敏。

## 验证

```bash
swift run TermPetLogicTests
swift build
```

## 上传到 GitHub

先在 GitHub 创建一个空仓库，然后在本地执行：

```bash
cd /Users/elevaene/code/vibe-coding-tools/TermPet
git init
git add .
git commit -m "Initial TermPet MVP"
git branch -M main
git remote add origin https://github.com/<your-user>/<your-repo>.git
git push -u origin main
```

如果你已经安装并登录了 GitHub CLI，也可以直接：

```bash
cd /Users/elevaene/code/vibe-coding-tools/TermPet
git init
git add .
git commit -m "Initial TermPet MVP"
gh repo create <your-user>/<your-repo> --public --source=. --remote=origin --push
```
