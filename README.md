<p align="center"><img src="Resources/AppIconSource.png" width="112" height="112" alt="Talis app icon"></p>

[English](README.md) | [简体中文](README.zh-CN.md) | [Español](README.es.md) | [Português do Brasil](README.pt-BR.md) | [日本語](README.ja.md) | [Français](README.fr.md) | [हिन्दी](README.hi.md)

# Talis

**Tired of writing prompts? You haven’t tried Talis.**

Talis is an open-source prompt editor for Mac. Press `Option + Space` to open it and jot down an idea. Use Grill-me to fill in missing details, Rewrite to organize a draft, or Refine to edit a selected passage. Then copy the prompt into the AI tool you already use. Save recurring requests as personal templates.

![The Talis editor with a rough invitation for a neighborhood book swap](https://viow.ai/additions/talis/assets/workflow-draft-en.webp)

[See the book swap example on the Talis website](https://viow.ai/work/talis/en/).

Current source version: `1.0.1` (Build 42).

Consecutive revisions use the latest 3 rounds as context. Open **Revision History** to review inputs and results from the current session. Use **Clear** in the editor to start a new task.

## Install

### Install from the DMG

Download the [Talis v1.0.1 DMG](https://github.com/viowai/7viow-talis/releases/download/v1.0.1/talis-v1.0.1-macos-arm64-build42.dmg). Open the disk image, drag `Talis.app` to **Applications**, then open it from **Applications**. The app requires Apple Silicon and macOS 13 or later.

The app is ad-hoc signed and is not notarized by Apple. If macOS blocks the first launch, confirm that you downloaded the app from this repository, then choose **Open Anyway** in **System Settings → Privacy & Security** if the option is available. See [Apple’s first-launch instructions](https://support.apple.com/en-us/102445). You can also build and install from source below.

The built app requires macOS 13 or later. Building it requires Xcode 26 or later developer tools, including the macOS 26 SDK or later. Apple Silicon is currently verified; Intel and other Macs have not been verified. Building does not require a paid Apple Developer membership. Talis has no third-party Swift Package dependencies.

### Ask a local AI agent to install it

Send this sentence to an agent that can run commands on the target Mac:

> Follow https://raw.githubusercontent.com/viowai/7viow-talis/main/docs/agent-install.en.md to install and open Talis on this Mac, preserve existing templates and settings, and guide me through first use.

Codex on the local Mac is verified. Claude Code, Cursor, Gemini CLI, VS Code local agents, and similar tools may work when they can execute commands on the target Mac, but they have not each been tested. Web-only chats and cloud Linux workspaces cannot install software on this Mac. See the [English agent installation guide](docs/agent-install.en.md).

### Install from source

In Terminal on the Mac:

```bash
git clone https://github.com/viowai/7viow-talis.git
cd 7viow-talis
bash scripts/install_app.sh && open /Applications/Talis.app
```

If Apple developer tools are missing, run `xcode-select --install` and complete the system prompt. If Talis is already open, save your text and quit it before installing. The installer keeps personal templates and settings separate from the app bundle. See [Installation and troubleshooting](docs/install.en.md) for details.

## First Use

Press `Option + Space` and try this draft:

> Help me write an invitation for a neighborhood book swap. Each person brings one book and takes a different one home. Leave the date and location for the organizer to fill in.

You can edit the draft and press `Command + Return` to copy it without setting up an AI service. To try the workflow shown on the website, open **AI Service Settings** from the gear button. Choose **API Key** or **Subscription**, select a service and region, then save.

1. **Grill-me** asks who the invitation is for. Choose an answer, write your own, or skip the question.
2. **Rewrite** organizes the draft into a prompt with a goal, requirements, and an output format.
3. **Refine** edits a selected passage, such as the line that explains how to leave the date and location open.
4. **Copy Prompt** puts the result on the clipboard. Press `Command + Return`, then paste it into your AI tool.

Use any of the three editing actions on its own. The result stays editable.

**Revision History** opens in a separate window. Open **Template Center** from the **Templates** menu to save a personal template or update its source template. Use the explicit **Apply** or **Replace** action; selecting a card does not apply it. Template replacement can be undone with `Command + Z`.

Placeholder brackets such as `【Field】` only provide highlighting and navigation. The brackets, colon, field name, and surrounding text are ordinary editable content. Tab moves to the next placeholder without rewriting the document.

## Choose a Starting Point

| Current situation | What to do |
|---|---|
| The idea is still vague | Write it first, then use Grill-me to add or skip details |
| The request is already written | Copy it, or use Refine or Rewrite to improve it |
| The same task repeats | Open Template Center from Templates, or press `Command + K`; press `/` in an empty editor |

System templates cover writing, editing, presentations, interface design and review, asset research, and research websites. Copy the finished Prompt into another AI tool or skill. Talis works independently; see [Using Talis with skills](docs/with-skills.en.md) for handoff examples.

## AI Services and Data

Editing, template selection, and copying work offline. Refine, Rewrite, Grill-me, and AI-generated templates require a reachable service. API-key providers bill through their own consoles. Subscription mode uses the AI product subscription already signed in on this Mac and does not require a separate API key.

API-key providers include DeepSeek, Kimi, MiniMax, OpenAI API, Anthropic, Google, xAI, Tencent Hunyuan, Baidu ERNIE, Alibaba Qwen, ByteDance Doubao, and Zhipu GLM. Subscription mode lists every service exposed by the local shared gateway; the verified current list is Codex, OpenAI, Kimi Work, and DeepSeek. New source installations default to DeepSeek.

Talis prefers official rolling model aliases. For providers without one, it may refresh the provider catalog and choose a current standard text model at most once every 24 hours. If a catalog request fails, Talis keeps the existing choice. Provider changes may still require an app update.

Model, account, region, and quota availability are controlled by each service. API keys are stored by provider in macOS Keychain. Subscription mode uses the local signed-in product and does not copy or save its OAuth token. See [AI service settings](docs/ai-services.en.md) and [Privacy and data](docs/privacy.en.md).

During AI processing, editing is locked and the main action changes to **Stop**. The original text is preserved when a request stops or fails, and a late response cannot overwrite newer edits.

## Shortcuts

| Action | Shortcut |
|---|---|
| Show or hide Talis | `Option + Space` |
| Open template search | `Command + K`, or `/` in an empty editor |
| Switch template source while searching | Tab |
| Move to the next placeholder | Tab |
| Insert the selected template | Return |
| Undo | `Command + Z` |
| Copy | `Command + Return` |
| Close template selection | Escape |
| End the current quick session and hide | Escape |
| Stop an AI request | `Command + .` |
| End Grill-me | `Command + .` |
| Save a template | `Command + S` |
| Save AI service settings | `Command + S` |

## Build and Check

Build without replacing the installed app:

```bash
bash scripts/build_desktop_app.sh
```

The output is in `~/Library/Caches/Talis/Build.noindex/desktop/Talis.app`. Check the local environment with `bash scripts/check_environment.sh`. Check installation prerequisites with `bash scripts/install_app.sh --check`. The preflight does not build, install, read API keys, or quit the running app.

## Boundaries and Feedback

Grill-me runs in a separate sheet, offers 1 to 3 questions per round, and supports up to 5 rounds. Information marked skipped remains unspecified. If the first round says no further detail is needed, Talis asks you to use the revised Prompt or return to the original text.

The latest 3 rounds are used as model context. Revision History retains every round in the current editing session. There is no cross-device sync or long-term memory. Escape, closing the window, or the global shortcut ends the current quick session; the next invocation starts blank. The latest text and revision history can be restored from **Restore Last Draft** while the app process remains open. A full app quit does not persist the ordinary draft.

The menu bar T is a monochrome template image. Click it to open or close Talis; right-click for New Prompt, Restore Last Draft, Revision History, Templates, Settings, About, and Quit.

Talis copies text into the clipboard. It does not send requests for you, transfer attachments, install or execute external skills, or prove that the receiving tool has run. Prompt Service and Talis Codex are not part of this desktop release.

For feedback, open a [GitHub Issue](https://github.com/viowai/7viow-talis/issues) with the app version, macOS version, chip type, steps, and error details. Remove API keys and private material first.

## License and Attribution

Maintainer: Viow. Talis is part of the 7viow product family. The app source and original documentation use the [Apache License 2.0](LICENSE), Copyright 2026 Wenbin Li. See [NOTICE](NOTICE) and [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). Montserrat is distributed under the SIL Open Font License 1.1.
