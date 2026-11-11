# Ask a Local AI Agent to Install Talis

[简体中文](agent-install.md) | [English](agent-install.en.md)

Talis is a macOS desktop app. The agent in this workflow builds and installs the source on your Mac. Once installed, you can copy a finished Prompt into any AI tool that accepts text.

## Send This Request

Send this sentence to an agent that can run commands on the target Mac:

> Follow https://raw.githubusercontent.com/viowai/7viow-talis/main/docs/agent-install.en.md to install and open Talis on this Mac, preserve existing templates and settings, and guide me through first use.

## Which Environments Can Help

The commands must execute on the Mac where Talis will be installed. The agent must be able to read the source and write the required app locations. A remote server, Linux container, cloud task, or read-only chat cannot install software on this Mac.

Codex on the local Mac is verified. Claude Code, Cursor, Gemini CLI, VS Code local agents, Devin Desktop, Windsurf, and similar environments may work when their commands run locally, but those integrations have not each been tested.

Installation does not require a Talis API key. For AI features, configure a provider key in the app or select **Subscription** and one of the services exposed by the local shared gateway. Do not send API keys, system passwords, or verification codes to the installation chat.

## Instructions for the Agent

### 1. Locate the Source

The repository is https://github.com/viowai/7viow-talis. Prefer the user's existing checkout. If a download is required, clone it into a normal source directory chosen by the user. Preserve existing local changes and do not overwrite unrelated files.

Confirm that the source root contains `Package.swift`, `Sources/`, and `scripts/install_app.sh`. Run:

```bash
bash scripts/install_app.sh --check
```

The source build requires Xcode 26 or later developer tools with the macOS 26 SDK or later. The built app still requires only macOS 13 or later. The preflight checks the system, Swift, SDK, tools, Applications write access, and whether Talis must be quit. It does not install, terminate the app, or read keys. Apple Silicon is verified; do not report Intel as verified.

If Apple developer tools are missing, ask the user to complete the system `xcode-select --install` flow. If Talis is running, ask the user to save unsaved text and quit normally. Do not force-terminate it. If Applications is not writable, continue with the [Finder installation path](install.en.md#install-with-finder-when-applications-is-not-writable).

### 2. Build, Install, and Open

When the prerequisites pass:

```bash
bash scripts/install_app.sh && open /Applications/Talis.app
```

The installer stages and verifies the new app, backs up the previous app, and restores it if replacement or final verification fails. Personal templates, settings, and macOS Keychain items remain separate. Do not delete those data stores or create a second permanent app entry.

To build without installing:

```bash
bash scripts/build_desktop_app.sh
```

Output is written to `~/Library/Caches/Talis/Build.noindex/desktop/Talis.app`.

Do not install extra skills, global hooks, Prompt Service, or Talis Codex. They are not runtime dependencies. Do not disable Gatekeeper or clear quarantine globally. When a downloaded app is blocked, explain its signing status and prefer the source-build path.

### 3. Verify and Hand Off

After installation, run:

```bash
codesign --verify --deep --strict /Applications/Talis.app
pgrep -fl '^/Applications/Talis.app/Contents/MacOS/PromptLibraryMac$'
```

An ad-hoc signature check is not Apple notarization. A running process does not prove every feature works. If the agent can see the GUI, confirm that the window opens. Otherwise ask the user to open it from Applications.

Tell the user the app location, the `Option + Space` shortcut, and the [First Use](../README.en.md#first-use) example. Start with the edit-and-copy flow that does not need an API key. Guide the user to **AI Service Settings** only when AI features are needed. Do not obtain or enter keys on the user's behalf and do not make a paid model request without explicit authorization.

If a step fails, report the exact failing step, whether the previous app is still present, and the next recovery action. Do not claim success before the installation is complete.
