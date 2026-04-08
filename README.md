<h1 align="center">
  <img src="docs/images/ping-island-icon.svg" width="64" height="64" alt="Ping Island app icon" valign="middle">&nbsp;
  Ping Island
</h1>
<p align="center">
  <b>Dynamic Island-style AI coding session monitor for the macOS menu bar</b><br>
  <a href="#installation">Install</a> •
  <a href="#features">Features</a> •
  <a href="#supported-tools">Supported Tools</a> •
  <a href="#build-from-source">Build</a><br>
  English | <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/erha19/ping-island/releases">
    <img src="https://img.shields.io/github/v/release/erha19/ping-island?display_name=tag&style=for-the-badge" alt="Latest release">
  </a>
  <img src="https://img.shields.io/badge/macOS-14%2B-0A84FF?style=for-the-badge&logo=apple&logoColor=white" alt="macOS 14 or later">
  <img src="https://img.shields.io/badge/Swift-6.1-FA7343?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 6.1">
  <img src="https://img.shields.io/badge/Clients-8%2B-111827?style=for-the-badge" alt="Supports 8 plus client families">
  <img src="https://img.shields.io/badge/License-Apache%202.0-4F46E5?style=for-the-badge" alt="Apache 2.0 license">
</p>

---

<p align="center">
  <img src="docs/images/notch-panel.png" width="480" alt="Ping Island preview">
</p>


<p align="center">
  <sub>Watch active coding sessions, answer follow-up questions, and jump back to the right terminal or IDE window.</sub>
</p>

<p align="center">
  <img src="docs/images/mascots/claude.gif" width="36" alt="Claude mascot" title="Claude Code">&nbsp;
  <img src="docs/images/mascots/codex.gif" width="36" alt="Codex mascot" title="Codex">&nbsp;
  <img src="docs/images/mascots/gemini.gif" width="36" alt="Gemini CLI mascot" title="Gemini CLI">&nbsp;
  <img src="docs/images/mascots/opencode.gif" width="36" alt="OpenCode mascot" title="OpenCode">&nbsp;
  <img src="docs/images/mascots/cursor.gif" width="36" alt="Cursor mascot" title="Cursor">&nbsp;
  <img src="docs/images/mascots/qoder.gif" width="36" alt="Qoder mascot" title="Qoder">&nbsp;
  <img src="docs/images/mascots/codebuddy.gif" width="36" alt="CodeBuddy mascot" title="CodeBuddy">&nbsp;
  <img src="docs/images/mascots/copilot.gif" width="36" alt="GitHub Copilot mascot" title="GitHub Copilot">
</p>
<p align="center">
  <sub>Claude Code · Codex · Gemini CLI · OpenCode · Cursor · Qoder · CodeBuddy · GitHub Copilot</sub>
</p>

## What is Ping Island?

Ping Island is a macOS menu bar app that expands into a Dynamic Island-style surface when your coding agents need attention. It listens to Claude-style hooks, Codex hooks, Gemini CLI hooks, the Codex app-server, OpenCode plugins, and compatible IDE integrations so approvals, input requests, completions, and session summaries show up without babysitting terminal tabs.

If you have seen [Vibe Island](https://vibeisland.app/), Ping Island is positioned as an independent open-source alternative in the same category: a native macOS notch/menu bar surface for monitoring and controlling AI coding sessions.

The app is built around a simple runtime flow:

```text
Hook / app-server event
  -> monitor and service layers
    -> SessionStore
      -> SessionMonitor + NotchViewModel
        -> notch UI, session list, hover preview, completion notifications
```

## Features

Ping Island is designed around the human-in-the-loop moments that actually break coding flow, then wraps them in a native macOS presentation that feels crisp instead of noisy.

| Signal First | Act In Place | Jump Back Precisely |
| --- | --- | --- |
| Stay compact until a session needs approval, input, or review, then expand into a Dynamic Island-style control surface that works on notch Macs and external displays. | Approve tools, deny requests, and answer follow-up prompts directly from the notch instead of digging through terminal tabs. | Return to the matching iTerm2, Ghostty, Terminal.app, tmux pane, or VS Code-compatible IDE window with the right session in context. |
| Multi-Client Coverage | Managed Integrations | Codex Beyond Hooks |
| Track Claude Code, Codex, Gemini CLI, OpenCode, Cursor, Qoder, CodeBuddy, GitHub Copilot, and compatible hook-driven sessions from one menu bar app. | Install or repair Claude, Codex, Gemini CLI, OpenCode, Qoder, CodeBuddy, Copilot, and related hook/plugin setups from Settings, including GitHub-style `.github/hooks/*.json` templates. | Support Codex CLI hooks plus live Codex app-server thread sync, with rollout parsing fallback when extra session context is needed. |

Additional polish that rounds out the workflow:

- **Client mascot system** - animated client mascots with per-client overrides and idle / working / warning states.
- **Sound packs and event audio** - built-in event sounds plus support for importing custom sound packs.
- **Sparkle updates and markdown release notes** - in-app update checks and version notes sourced from the release pipeline.
- **Diagnostics export** - bundle recent logs and config into a zip when you need to debug a broken integration.

<a id="supported-tools"></a>
## Supported Tools

| Icon | Tool | Ingress | Jump | Coverage |
|:---:|------|---------|------|----------|
| <img src="docs/images/product-icons/claude-app-icon.png" width="32" alt="Claude Code product icon"> | Claude Code | Claude hooks | Terminal, tmux, IDE-hosted terminal | approvals, questions, compacting, completion |
| <img src="PingIsland/Assets.xcassets/CodexLogo.imageset/codex-logo.png" width="32" alt="Codex product icon"> | Codex App + Codex CLI | Codex app-server, hooks, rollout parsing fallback | Codex app, terminal | approvals, input requests, thread sync |
| <img src="PingIsland/Assets.xcassets/GeminiLogo.imageset/gemini-logo.png" width="32" alt="Gemini CLI product icon"> | Gemini CLI | Gemini CLI hooks (`~/.gemini/settings.json`) | Compatible terminal host | session lifecycle, tool activity, notifications, compaction |
| <img src="docs/images/product-icons/opencode-app-icon.png" width="32" alt="OpenCode product icon"> | OpenCode | Managed plugin file | OpenCode app, terminal | forwarded plugin events into the same Island surface |
| <img src="docs/images/product-icons/cursor-app-icon.png" width="32" alt="Cursor product icon"> | Cursor | Claude-compatible hooks + optional IDE extension | Project window + matching terminal | IDE routing and terminal focus |
| <img src="PingIsland/Assets.xcassets/QoderLogo.imageset/qoder-logo.png" width="32" alt="Qoder product icon"> | Qoder/QoderWork/... | Qoder, QoderWork, Qoder CLI, JetBrains-compatible paths | Qoder / QoderWork window, terminal | session jump, approvals, reminders |
| <img src="docs/images/product-icons/codebuddy-app-icon.png" width="32" alt="CodeBuddy product icon"> | CodeBuddy | Hook integration + optional IDE extension | App window + terminal | tracked Claude-family sessions |
| <img src="PingIsland/Assets.xcassets/CopilotLogo.imageset/copilot-logo.png" width="32" alt="GitHub Copilot product icon"> | GitHub Copilot | GitHub Copilot hooks (`.github/hooks/*.json`) | Compatible terminal host | Copilot CLI / agent hook events |

Ping Island also ships VS Code-compatible focus extensions for VS Code, Cursor, CodeBuddy, Qoder, and QoderWork. `QoderWork` remains hook-first and is only treated as an IDE extension host when that environment is actually available.

The mascot GIFs used throughout this README are generated from the live `MascotView` implementation via `./scripts/render-mascots.sh`.

<a id="installation"></a>
## Installation

### Download a Release

1. Go to [Releases](https://github.com/erha19/ping-island/releases).
2. Download the latest DMG or zip package.
3. Move `Ping Island.app` into your Applications folder.
4. Launch the app, then open **Settings -> Integration** to install the integrations you want.

> On first launch, macOS may ask you to confirm the app or grant Accessibility / Apple Events permissions for focus features.

<a id="build-from-source"></a>
### Build from Source

Requires macOS 14+ and an Xcode toolchain that can build the Xcode project and the Swift 6.1 `Prototype` package tests.

```bash
git clone https://github.com/erha19/ping-island.git
cd ping-island

# Debug build
xcodebuild -project PingIsland.xcodeproj -scheme PingIsland -configuration Debug build

# Release build
xcodebuild -project PingIsland.xcodeproj -scheme PingIsland -configuration Release build
```

To create a locally shareable unsigned package:

```bash
./scripts/package-unsigned.sh
```

For the full notarized release flow and Sparkle appcast setup, see [docs/sparkle-release.md](docs/sparkle-release.md).

## Testing

The fastest full-repo regression path is:

```bash
./scripts/test.sh
```

That covers:

```bash
swift test --package-path Prototype
xcodebuild -project PingIsland.xcodeproj -scheme PingIsland -configuration Debug CODE_SIGNING_ALLOWED=NO test -only-testing:PingIslandTests
xcodebuild -project PingIsland.xcodeproj -scheme PingIsland -configuration Debug CODE_SIGN_IDENTITY=- test
```

Useful targeted slices:

```bash
swift test --package-path Prototype --filter IslandBridgeE2ETests
xcodebuild -project PingIsland.xcodeproj -scheme PingIsland -configuration Debug CODE_SIGNING_ALLOWED=NO test -only-testing:PingIslandTests
xcodebuild -project PingIsland.xcodeproj -scheme PingIsland -configuration Debug CODE_SIGN_IDENTITY=- test -only-testing:PingIslandUITests
```

If `PingIslandUITests-Runner` stays suspended on macOS, run the UI tests from Xcode with a valid local signing identity and check `amfid` / `AppleSystemPolicy` logs before treating it as an app regression.

## Settings

Ping Island currently ships a 6-category settings panel:

- **General** - launch at login, baseline app behavior, diagnostics export
- **Display** - notch display target and placement behavior
- **Mascot** - client mascot previews, per-client overrides, animation states
- **Sound** - event-specific sounds, sound pack mode, sound pack import
- **Integration** - hooks, plugin installs, IDE extension installs, accessibility guidance
- **About** - app version, update state, release notes, update actions

## How It Works

```text
Claude / Codex / Gemini CLI / OpenCode / Cursor / Qoder / CodeBuddy / Copilot / ...
  -> hook or app-server event
    -> Ping Island monitor + normalization layer
      -> SessionStore
        -> SessionMonitor / NotchViewModel
          -> notch, list, hover preview, completion popup
```

Implementation details worth knowing:

- Claude-family tools enter through managed hook files plus `PingIsland/Resources/island-state.py`.
- Codex sessions can come from hook events or the live `codex app-server` websocket monitor.
- Gemini CLI hooks are installed into `~/.gemini/settings.json`; tool matchers use Gemini's regex-based hook matcher syntax.
- OpenCode is wired through a generated plugin file under `~/.config/opencode/plugins/`.
- Focus routing spans iTerm2, Ghostty, Terminal.app, tmux, and VS Code-compatible IDE extensions.

## Requirements

- macOS 14.0 or later
- Best experience on MacBooks with a notch, but external displays are supported too
- Install whichever CLI or desktop clients you want Ping Island to monitor

## Acknowledgments

Ping Island follows the lineage of notch-first agent monitors such as [claude-island](https://github.com/farouqaldori/claude-island), and adapts that idea into a broader multi-client session surface with hooks, app-server sync, and IDE routing.

## License

Apache 2.0 - see [LICENSE.md](LICENSE.md).
