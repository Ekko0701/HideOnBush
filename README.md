<h1 align="center">HideOnBush</h1>

<p align="center">
  A tiny macOS menu bar app for switching approved Claude OTel settings between Work Mode and Personal Mode.
</p>

<p align="center">
  <a href="https://github.com/Ekko0701/HideOnBush/releases/latest">
    <img alt="Latest release" src="https://img.shields.io/badge/release-v0.1.0-blue?style=flat-square">
  </a>
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey?style=flat-square">
  <img alt="Architecture" src="https://img.shields.io/badge/arch-Apple%20Silicon-lightgrey?style=flat-square">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6-orange?style=flat-square">
</p>

## Features

- Native macOS menu bar app.
- Switch Claude OTel telemetry settings between Work Mode and Personal Mode.
- Controls shell profile exports, LaunchAgent configuration, and `launchctl` GUI environment values.
- Backs up the existing Work configuration on first launch and restores it when Work Mode is enabled.
- Shows the current state of shell profile, LaunchAgent, and GUI environment in the menu.
- Copies a compact status report to the clipboard for troubleshooting.
- No background network calls from HideOnBush itself.

## Download

Install with Homebrew:

```bash
brew tap Ekko0701/hideonbush https://github.com/Ekko0701/HideOnBush.git
brew trust --tap ekko0701/hideonbush
brew install --cask hideonbush
```

Or download the latest ZIP from [GitHub Releases](https://github.com/Ekko0701/HideOnBush/releases).

> Homebrew may refuse casks from non-official taps unless the tap is trusted locally.

## How It Works

HideOnBush manages the same places that are commonly used to inject Claude OTel variables on macOS:

- Shell profile: `~/.zshrc`, `~/.bash_profile`, or `~/.bashrc`
- LaunchAgent: `~/Library/LaunchAgents/com.megastudy.otel.plist`
- GUI environment: `launchctl setenv` / `launchctl unsetenv`

Clean installs start in Personal Mode. Work Mode is only enabled when you explicitly select it from the menu.

Work Mode restores the backed-up Claude OTel shell block and LaunchAgent, then sets the GUI environment values.

Personal Mode removes the shell block, unloads and removes the LaunchAgent, then clears the tracked GUI environment values.

Already-running apps keep their old environment. After switching modes, fully quit and reopen Claude Desktop, VSCode, Cursor, JetBrains IDEs, Terminal, or iTerm.

## Menu

- `Personal Mode로 전환`
- `Work Mode로 전환`
- `상태 새로고침`
- `상태 클립보드에 복사`
- `셸 프로파일 열기`
- `LaunchAgents 폴더 열기`

## Backup Location

On first launch, HideOnBush stores the current Work configuration under:

```text
~/Library/Application Support/HideOnBush
```

When Work Mode is enabled, HideOnBush prefers this backup so existing company-provided values are preserved.

## Build From Source

```bash
./scripts/build.sh
```

The app bundle is written to:

```text
dist/HideOnBush.app
```

Run locally:

```bash
./scripts/run.sh
```

## Homebrew Release

Create a release ZIP and a cask file:

```bash
./scripts/package-homebrew.sh 0.1.0
```

Generated files:

```text
release/HideOnBush-v0.1.0-macos-arm64.zip
release/homebrew/Casks/hideonbush.rb
```

Release flow:

1. Create a GitHub Release such as `v0.1.0`.
2. Upload `HideOnBush-v0.1.0-macos-arm64.zip`.
3. Commit the generated cask file to `Casks/hideonbush.rb`.

The repository or release asset must be accessible to Homebrew. For public distribution, keep the GitHub repository public.

For official macOS distribution, use a Developer ID Application certificate and notarize the app:

```bash
./scripts/release-notarized.sh 0.1.0
```

## Have a Problem?

Open an issue on [GitHub Issues](https://github.com/Ekko0701/HideOnBush/issues).

---

HideOnBush is designed for approved personal/work mode switching on macOS devices where Claude OTel configuration is managed through user-level shell profile and LaunchAgent settings.
