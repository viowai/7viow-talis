# 请 AI agent 帮你安装 Talis

Talis 是 macOS 桌面 App。这里的 agent 负责在你的 Mac 上完成源码构建与安装。日常使用时，你可以把 Talis 整理的文字复制给任意支持文本输入的 AI 工具。

## 复制这一句

在能够操作目标 Mac 终端的 agent 中，发送下面这句话：

> 请按 https://raw.githubusercontent.com/viowai/7viow-talis/main/docs/agent-install.md 中的说明，在我的这台 Mac 上安装并打开 Talis，保留已有模板和设置，并带我完成第一次使用。

## 哪些 agent 可以协助

关键条件是：**命令实际运行在你要安装 Talis 的 Mac 上**，能读取源码，并拥有所需的文件写入权限。远程服务器、Linux 容器、云端任务和只读聊天不能代替这台 Mac 执行安装。

| 使用环境 | 安装路径 | 验证范围 |
|---|---|---|
| Codex 本机任务 | 打开源码或提供仓库链接，按本指引运行终端命令 | 本机 Apple Silicon 构建、安装与打开已验证。公开源码获取与构建按本指引执行 |
| [Claude Code 本机终端 / IDE](https://code.claude.com/docs/en/overview) | 允许访问源码及执行本机命令 | 有官方能力依据，尚未逐宿主实测 |
| [Cursor 本机 Agent](https://cursor.com/docs/agent/tools/terminal) | 打开源码，在可执行终端命令的模式下使用 | 有官方能力依据，尚未逐宿主实测 |
| [Gemini CLI](https://geminicli.com/docs/tools/shell/) | 在本机终端中读取仓库，允许所需 shell 命令 | 有官方能力依据，尚未逐宿主实测 |
| [VS Code 本地 agent](https://code.visualstudio.com/docs/agents/run/agent-harnesses) | 选择本机执行环境，允许终端和安装目录访问 | 有官方能力依据，尚未逐宿主实测 |
| [Devin Desktop / Windsurf 本地执行环境](https://docs.devin.ai/desktop/terminal) | 确认命令由本机执行，按其权限模式授权 | 官方文档已迁至 Devin Desktop。未逐宿主实测 |
| 其他能操作本机终端的 agent | 先验证相同环境条件，再使用本指引 | 未验证 |
| 仅网页聊天 / 云端 Linux 工作区 | 可以解释步骤。请在 Mac 本机执行[安装说明](install.md) | 无直接安装到这台 Mac 的能力 |

安装不需要 Talis 的 API Key。首次使用 AI 时，由你在 App 设置中填写。不要把 Key、系统密码或验证码交给安装对话。

## 给执行安装的 agent

### 1. 定位源码和执行环境

源码仓库是 https://github.com/viowai/7viow-talis 。优先使用用户已下载的这份源码。需要下载时，克隆到用户选择的位置或普通源码缓存目录。如果目标目录已存在，先确认它属于本仓库并保留本地修改，不覆盖其他文件。应用程序目录只放最终 App。

确认源码根中存在 `Package.swift`、`Sources/` 和 `scripts/install_app.sh`。在该目录执行：

```bash
bash scripts/install_app.sh --check
```

该命令检查 macOS 13+、Swift 5.9+、macOS SDK、构建工具、安装目录权限及现用 Talis 是否已退出。只检查，不安装、不关闭应用、不读取密钥。当前验证仅覆盖 Apple Silicon，不能把 Intel 构建报告为已验证。

如果缺少 Apple 开发工具，说明需要用户在系统窗口完成 `xcode-select --install`。如果 Talis 正在运行，让用户先保留未复制的文字并退出。不要强制终止。写入权限不足时按 [Finder 安装路径](install.md#权限不足时用-finder-安装)继续。

### 2. 构建、安装并打开

条件满足后执行：

```bash
bash scripts/install_app.sh && open /Applications/Talis.app
```

安装器先完整复制并校验新 App，再把原 App 保留到应用数据目录的 `Backups` 后替换。替换或最终校验失败时恢复原 App。恢复受阻时，错误信息会给出备份位置。个人模板、设置和 Keychain 独立保存。不要删除这些数据或创建替代的日常入口。

仅需构建时使用 `bash scripts/build_desktop_app.sh`。构建输出在 `~/Library/Caches/Talis/Build/desktop/Talis.app`。此操作不替换日常 App。

不要安装额外 skill/s、全局 Hook、Prompt Service 或 Talis Codex。这些不是桌面 App 的运行依赖。不要更改系统 Gatekeeper 或执行全局隔离属性清除命令。下载包被系统拦截时，按来源与签名状态解释，优先使用这里的源码构建路径。

### 3. 确认结果并交给用户

检查安装命令是否成功，并运行：

```bash
codesign --verify --deep --strict /Applications/Talis.app
pgrep -fl '^/Applications/Talis.app/Contents/MacOS/PromptLibraryMac$'
```

本地临时签名验证不等于 Apple 公证。进程存在也不等于所有功能正常：能查看界面时确认窗口能打开。不能查看时，明确请用户从“应用程序”打开确认。

告诉用户 App 的位置、`Option + Space` 唤起方式，以及 [README 的首次使用示例](../README.md#完成第一次使用)。先完成无需 API Key 的编辑与复制。用户需要 AI 功能时再引导到“设置 AI 模型”。不替用户获取或填写 Key，不额外发起付费模型请求。

失败时说明具体卡在哪一步、已有 App 是否仍在、下一步如何继续。没有完成安装就不要报告安装成功。
