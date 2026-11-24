# Installation and Troubleshooting

[简体中文](install.md) | [English](install.en.md)

This release provides a prebuilt app and a source installation. The prebuilt package requires macOS 13 or later and is verified only on Apple Silicon. Building from source requires Xcode 26 or later developer tools with the macOS 26 SDK or later. Intel and other Macs have not been verified.

To hand installation to a local AI agent, use the [English agent installation guide](agent-install.en.md). To install yourself:

## Install from the DMG

1. Download the [Talis v1.1.1 DMG](https://github.com/viowai/7viow-talis/releases/download/v1.1.1/talis-v1.1.1-macos-arm64-build45.dmg). When upgrading, save any text you are editing and quit Talis first.
2. Open the DMG, drag `Talis.app` onto the **Applications** shortcut in the disk image, then open it from **Applications**.
3. The app is ad-hoc signed and is not notarized by Apple. If macOS blocks the first launch, confirm that you downloaded the app from this repository, then choose **Open Anyway** in **System Settings → Privacy & Security** if the option is available. See [Apple’s first-launch instructions](https://support.apple.com/en-us/102445).

Talis 1.1.1 keeps your personal templates, language and provider settings, and existing Keychain entries. Save any draft or revision history you need before quitting. macOS may ask you to allow Keychain access again.

The [app ZIP](https://github.com/viowai/7viow-talis/releases/download/v1.1.1/talis-v1.1.1-macos-arm64-build45.zip) is an alternate download. Unzip it, move `Talis.app` to **Applications**, and follow the same first-launch steps.

## Install from Source

1. Clone the [GitHub repository](https://github.com/viowai/7viow-talis), or download and extract the ZIP. Open Terminal in the directory containing `Package.swift`.
2. Check the environment:

```bash
bash scripts/install_app.sh --check
```

If Apple developer tools are missing, run `xcode-select --install` and complete the macOS prompt. If full Xcode is already installed, separate Command Line Tools may not be required. Complete any license prompt yourself. See [Installing Apple command-line tools](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools).

3. Save any text being edited, quit the existing Talis app, and run:

```bash
bash scripts/install_app.sh && open /Applications/Talis.app
```

The installation itself does not require an API key or a paid Apple Developer membership. Follow [First Use](../README.en.md#first-use) to edit and copy a sample before configuring AI.

## Daily Use

The standard app location is `/Applications/Talis.app`. Open it from Applications, Spotlight, or the Dock. Source builds use `Option + Space`.

| Item | Location |
|---|---|
| App | `/Applications/Talis.app` |
| Personal templates and app configuration | `~/Library/Application Support/Talis` |
| API keys | macOS Keychain, separated by provider |
| Build cache and local package output | `~/Library/Caches/Talis/Build.noindex` |

The installer copies the new app into a staging location, verifies it, creates and verifies a ZIP backup of the previous app, and then replaces the bundle. It restores the previous app if replacement or final verification fails. Successful upgrades leave the previous app in `~/Library/Application Support/Talis/Backups/Archives.noindex/<timestamp>/AppBundle.zip`. Personal templates and settings remain separate.

## Install with Finder when /Applications is not writable

Build first:

```bash
bash scripts/build_desktop_app.sh
open "$HOME/Library/Caches/Talis/Build.noindex/desktop"
```

Quit the running app. Back up an existing app before replacing it:

```bash
ditto -c -k --rsrc --extattr --acl --sequesterRsrc /Applications/Talis.app "$HOME/Talis-backup.zip"
```

In Finder, drag the new `Talis.app` into Applications and complete the macOS administrator prompt. Do not send a password to an AI agent.

## Build Only

```bash
bash scripts/build_desktop_app.sh
```

The app is written to `~/Library/Caches/Talis/Build.noindex/desktop/Talis.app`. The first build can take several minutes. There are no external Swift Package dependencies.

## Common Problems

| Symptom | Next step |
|---|---|
| `scripts/install_app.sh` is missing | Change to the extracted source root containing `Package.swift` |
| macOS is required | The command is running on Windows, Linux, or a cloud environment. Use Terminal or a local agent on the target Mac |
| Swift or macOS SDK is missing | Complete the Apple developer-tools installation, then run `bash scripts/check_environment.sh` |
| Tools appear installed but the build still fails | Check `xcode-select -p`, `swift --version`, and `xcrun --sdk macosx --show-sdk-path` |
| The installer asks to quit Talis | Save or copy your text, quit normally, and retry. The installer does not force-quit the app |
| Cannot write to Applications | Use the Finder path above |
| Gatekeeper blocks a downloaded app | See [Install from the DMG](#install-from-the-dmg) for macOS’s **Open Anyway** step. If unavailable, use [Install from Source](#install-from-source). |
| The app opens but AI actions fail | Check the selected provider and key in Settings. Installation and service availability are separate conditions |
| `Option + Space` does not show Talis | Open from the menu bar or Dock. If the app reports that the global shortcut is unavailable, check for a conflicting app and record the error code |

For help, open a [GitHub Issue](https://github.com/viowai/7viow-talis/issues) with the app version, macOS version, chip type, command, and error. Do not include API keys, private templates, or complete personal configuration.

## Local ZIP and Disk Image

```bash
bash scripts/package_local.sh
```

Output is written to `~/Library/Caches/Talis/Build.noindex/packages`. Packages use an ad-hoc local signature, not Developer ID signing or Apple notarization. Gatekeeper may block them on another Mac.

## Update and Restore

Quit the app before updating. The installer replaces only the app bundle; personal data remains separate. Back up current data before restoring an old app, because older versions may not understand newer provider-key storage.

To uninstall the app, remove `/Applications/Talis.app`. To remove a provider key, select that provider in Settings and choose **Remove API Key**. Keep the app data directory if you need your personal templates.

To restore a ZIP backup, quit the app and extract it into an empty restore directory:

```bash
mkdir -p "$HOME/Library/Caches/Talis/Restore.noindex"
ditto -x -k --rsrc --extattr --acl "/path/to/AppBundle.zip" \
  "$HOME/Library/Caches/Talis/Restore.noindex/Talis.app"
```

Use a new empty directory for each restore. Verify the version, data identity, and signature before installing the restored app. Keep the source ZIP unchanged.
