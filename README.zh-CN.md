<h1 align="center">
  <img src="docs/images/ping-island-icon.svg" width="64" height="64" alt="Ping Island 应用图标" valign="middle">&nbsp;
  Ping Island
</h1>
<p align="center">
  <b>macOS 菜单栏里的 Dynamic Island 风格 AI 编码会话监视器</b><br>
  <a href="#installation">安装</a> •
  <a href="#features">功能</a> •
  <a href="#question-flow">问答示例</a> •
  <a href="#supported-tools">支持的工具</a> •
  <a href="#build-from-source">构建</a><br>
  <a href="README.md">English</a> | 简体中文
</p>

---

<p align="center">
  <img src="docs/images/notch-panel.png" width="960" alt="Ping Island 预览图">
</p>
<p align="center">
  <sub>在菜单栏里查看活跃编码会话、回答追问，并一键跳回正确的终端或 IDE 窗口。</sub>
</p>

<p align="center">
  <img src="docs/images/product-icons/claude-app-icon.png" width="28" alt="Claude Code 图标" title="Claude Code">&nbsp;
  <img src="PingIsland/Assets.xcassets/CodexLogo.imageset/codex-logo.png" width="28" alt="Codex 图标" title="Codex">&nbsp;
  <img src="PingIsland/Assets.xcassets/GeminiLogo.imageset/gemini-logo.png" width="28" alt="Gemini CLI 图标" title="Gemini CLI">&nbsp;
  <img src="docs/images/product-icons/opencode-app-icon.png" width="28" alt="OpenCode 图标" title="OpenCode">&nbsp;
  <img src="docs/images/product-icons/cursor-app-icon.png" width="28" alt="Cursor 图标" title="Cursor">&nbsp;
  <img src="PingIsland/Assets.xcassets/QoderLogo.imageset/qoder-logo.png" width="28" alt="Qoder 图标" title="Qoder">&nbsp;
  <img src="docs/images/product-icons/codebuddy-app-icon.png" width="28" alt="CodeBuddy 图标" title="CodeBuddy">&nbsp;
  <img src="PingIsland/Assets.xcassets/CopilotLogo.imageset/copilot-logo.png" width="28" alt="GitHub Copilot 图标" title="GitHub Copilot">
</p>
<p align="center">
  <sub>Claude Code · Codex · Gemini CLI · OpenCode · Cursor · Qoder · CodeBuddy · GitHub Copilot</sub>
</p>

## Ping Island 是什么？

Ping Island 是一个 macOS 菜单栏应用。当你的编码 Agent 需要你处理审批、输入或查看结果时，它会展开成一个类似 Dynamic Island 的悬浮界面。它能接 Claude 风格 hooks、Codex hooks、Gemini CLI hooks、Codex app-server、OpenCode 插件，以及兼容 IDE 的集成层，所以你不用一直盯着终端标签页，也能看到会话状态。

如果你了解过 [Vibe Island](https://vibeisland.app/)，可以把 Ping Island 理解成同一产品方向下的独立开源替代方案：它同样是一个原生 macOS 刘海区 / 菜单栏界面，用来监控和控制 AI 编码会话。

项目当前的主运行链路很直接：

```text
Hook / app-server 事件
  -> 监控与服务层
    -> SessionStore
      -> SessionMonitor + NotchViewModel
        -> 刘海 UI、会话列表、hover 预览、完成提醒
```

<a id="features"></a>
## 功能特性

- **Dynamic Island 风格菜单栏 UI** - 默认紧凑展示，会话需要你介入时自动展开；支持刘海屏和外接显示器。
- **多客户端会话监控** - 可跟踪 Claude Code、Codex、Gemini CLI、OpenCode、Cursor、Qoder、CodeBuddy、GitHub Copilot 以及兼容 hooks 的会话。
- **就地审批与回答** - 在刘海界面里直接批准、拒绝或回答，不用切回终端。
- **终端和 IDE 跳转** - 支持把你带回对应的 iTerm2、Ghostty、Terminal.app、tmux pane，或 VS Code 兼容 IDE 窗口。
- **托管集成安装** - 可在设置页里安装或修复 Claude、Codex、Gemini CLI、OpenCode、Qoder、CodeBuddy、Copilot 等 hooks / 插件集成。
- **Codex 双通路支持** - 同时覆盖 Codex CLI hooks 和 Codex app-server 线程同步，并带 rollout 解析兜底。
- **客户端宠物系统** - 每类客户端有自己的动画宠物，还支持按客户端自定义覆盖，并区分空闲 / 运行 / 警告三种状态。
- **声音包与事件提示音** - 可按事件配置声音，也可导入自定义 sound pack。
- **Sparkle 自动更新** - 支持应用内更新检查与 Markdown 版本说明。
- **诊断包导出** - 一键导出最近日志和配置，方便排查集成问题。

<a id="question-flow"></a>
## 就地回答问题

当 Claude Code、Codex 或其他受支持客户端需要你补充上下文时，Ping Island 会直接在菜单栏里展示问题、选项和待处理会话。你可以原地补答并提交，让原会话继续执行，而不用来回找终端标签页。

<p align="center">
  <img src="docs/images/question-panel.png" width="860" alt="Ping Island 提问界面示例">
</p>

<a id="supported-tools"></a>
## 支持的工具

| 图标 | 工具 | 接入方式 | 跳转 | 覆盖范围 |
|:---:|------|----------|------|----------|
| <img src="docs/images/product-icons/claude-app-icon.png" width="32" alt="Claude Code 产品图标"> | Claude Code | Claude hooks | 终端、tmux、IDE 内终端 | 审批、提问、压缩、完成提醒 |
| <img src="PingIsland/Assets.xcassets/CodexLogo.imageset/codex-logo.png" width="32" alt="Codex 产品图标"> | Codex App + Codex CLI | Codex app-server、hooks、rollout 解析兜底 | Codex 应用、终端 | 审批、输入请求、线程同步 |
| <img src="PingIsland/Assets.xcassets/GeminiLogo.imageset/gemini-logo.png" width="32" alt="Gemini CLI 产品图标"> | Gemini CLI | Gemini CLI hooks（`~/.gemini/settings.json`） | 兼容终端宿主 | 会话生命周期、工具活动、通知、压缩前事件 |
| <img src="docs/images/product-icons/opencode-app-icon.png" width="32" alt="OpenCode 产品图标"> | OpenCode | 托管插件文件 | OpenCode 应用、终端 | 插件事件转发到同一套 Island UI |
| <img src="docs/images/product-icons/cursor-app-icon.png" width="32" alt="Cursor 产品图标"> | Cursor | Claude 兼容 hooks + 可选 IDE 扩展 | 项目窗口 + 对应终端 | IDE 路由与终端精准聚焦 |
| <img src="PingIsland/Assets.xcassets/QoderLogo.imageset/qoder-logo.png" width="32" alt="Qoder 产品图标"> | Qoder/QoderWork/... | Qoder、QoderWork、Qoder CLI、JetBrains 兼容路径 | Qoder / QoderWork 窗口、终端 | 会话跳转、审批、提醒 |
| <img src="docs/images/product-icons/codebuddy-app-icon.png" width="32" alt="CodeBuddy 产品图标"> | CodeBuddy | Hook 集成 + 可选 IDE 扩展 | 应用窗口 + 终端 | Claude 家族会话跟踪 |
| <img src="PingIsland/Assets.xcassets/CopilotLogo.imageset/copilot-logo.png" width="32" alt="GitHub Copilot 产品图标"> | GitHub Copilot | Copilot hook 协议 | 兼容终端宿主 | Copilot CLI / Agent hooks 事件 |

Ping Island 另外还提供 VS Code 兼容的聚焦扩展，可用于 VS Code、Cursor、CodeBuddy、Qoder 和 QoderWork。`QoderWork` 目前仍然以 hook 接入为主，只有在对应 IDE 宿主可用时才会走扩展路径。

<a id="installation"></a>
## 安装

### 下载发行版

1. 打开 [Releases](https://github.com/erha19/ping-island/releases)
2. 下载最新的 DMG 或 zip 包
3. 将 `Ping Island.app` 拖到 Applications
4. 启动应用后，进入 **Settings -> Integration** 安装你需要的集成

> 首次启动时，macOS 可能会要求你确认应用，或授予辅助功能 / Apple Events 权限以支持聚焦能力。

<a id="build-from-source"></a>
### 从源码构建

需要 macOS 14+，以及能同时构建 Xcode 工程和 Swift 6.1 `Prototype` 测试包的 Xcode 工具链。

```bash
git clone https://github.com/erha19/ping-island.git
cd ping-island

# Debug 构建
xcodebuild -project PingIsland.xcodeproj -scheme PingIsland -configuration Debug build

# Release 构建
xcodebuild -project PingIsland.xcodeproj -scheme PingIsland -configuration Release build
```

如果你想产出本地分发用的未签名安装包：

```bash
./scripts/package-unsigned.sh
```

完整的 Sparkle / notarization 发布流程见 [docs/sparkle-release.md](docs/sparkle-release.md)。

## 测试

整仓库的最快完整回归入口是：

```bash
./scripts/test.sh
```

它会覆盖：

```bash
swift test --package-path Prototype
xcodebuild -project PingIsland.xcodeproj -scheme PingIsland -configuration Debug CODE_SIGNING_ALLOWED=NO test -only-testing:PingIslandTests
xcodebuild -project PingIsland.xcodeproj -scheme PingIsland -configuration Debug CODE_SIGN_IDENTITY=- test
```

常用分片：

```bash
swift test --package-path Prototype --filter IslandBridgeE2ETests
xcodebuild -project PingIsland.xcodeproj -scheme PingIsland -configuration Debug CODE_SIGNING_ALLOWED=NO test -only-testing:PingIslandTests
xcodebuild -project PingIsland.xcodeproj -scheme PingIsland -configuration Debug CODE_SIGN_IDENTITY=- test -only-testing:PingIslandUITests
```

如果 `PingIslandUITests-Runner` 在 macOS 上一直停在 suspended，优先在 Xcode 里用有效本地签名身份跑 UI 测试，并结合 `amfid` / `AppleSystemPolicy` 日志判断是不是代码签名或系统策略问题。

## 设置面板

Ping Island 当前提供 6 个设置分类：

- **General** - 登录启动、基础行为、诊断导出
- **Display** - 显示器选择与位置行为
- **Mascot** - 宠物预览、客户端覆盖、动作状态
- **Sound** - 事件声音、声音包模式、声音包导入
- **Integration** - hooks、插件安装、IDE 扩展安装、辅助功能引导
- **About** - 版本、更新状态、版本说明、更新操作

## 工作原理

```text
Claude / Codex / Gemini CLI / OpenCode / Cursor / Qoder / CodeBuddy / Copilot / ...
  -> hook 或 app-server 事件
    -> Ping Island 监控与归一化层
      -> SessionStore
        -> SessionMonitor / NotchViewModel
          -> 刘海、列表、hover 预览、完成提示
```

几个实现细节：

- Claude 家族工具主要通过托管 hook 文件和 `PingIsland/Resources/island-state.py` 接入。
- Codex 会话既可以来自 hooks，也可以来自 `codex app-server` websocket 实时同步。
- Gemini CLI hooks 会安装到 `~/.gemini/settings.json`，其中工具 matcher 要使用 Gemini 的正则语法。
- OpenCode 使用生成到 `~/.config/opencode/plugins/` 下的插件文件接入。
- 聚焦路由覆盖 iTerm2、Ghostty、Terminal.app、tmux 和 VS Code 兼容 IDE 扩展。

## 系统要求

- macOS 14.0 或更高
- 在带刘海的 MacBook 上体验最好，但也支持外接显示器
- 安装你希望 Ping Island 监控的 CLI 或桌面客户端

## 致谢

Ping Island 延续了 [claude-island](https://github.com/farouqaldori/claude-island) 这类刘海式 Agent 监视器的思路，并把它扩展到了多客户端 hooks、Codex app-server 同步和 IDE 路由能力上。

## 许可证

Apache 2.0，详见 [LICENSE.md](LICENSE.md)。
