<p align="center"><img src="Resources/AppIconSource.png" width="112" height="112" alt="Talis 应用图标"></p>

[English](README.md) | [简体中文](README.zh-CN.md) | [Español](README.es.md) | [Português do Brasil](README.pt-BR.md) | [日本語](README.ja.md) | [Français](README.fr.md) | [हिन्दी](README.hi.md)

# Talis

**写 prompt 累？因为你还没用 Talis。**

Talis 是 Mac 上的开源 Prompt 编辑器。按 `Option + Space` 唤起，先把想法写下来。缺细节就追问，内容零散就重构，想改其中一段就选中微调。改好后复制到常用的 AI 工具。反复用到的请求可以存成个人模板。

<p align="left"><a href="https://viow.ai/work/talis/"><img src="https://viow.ai/additions/talis/assets/provider-launch-draft-zh.webp" width="480" alt="Talis 编辑器里的 v1.0.0 发布草稿"></a></p>

[在官网看 Talis v1.0.0 发布案例的演示](https://viow.ai/work/talis/)。

当前源码版本：`1.0.2`（Build 43）。

连续修改会结合最近 3 轮上下文。打开“修改记录”可在独立窗口回看输入与结果；开始新任务时，用内容区的“清空”按钮。

## 安装

### 用 DMG 安装

下载 [Talis v1.0.2 DMG](https://github.com/viowai/7viow-talis/releases/download/v1.0.2/talis-v1.0.2-macos-arm64-build43.dmg)。打开磁盘映像，把 `Talis.app` 拖到「应用程序」，再从「应用程序」打开 Talis。需要 Apple Silicon 和 macOS 13 或更新版本。

应用使用 ad-hoc 签名，未经 Apple 公证。如果首次打开时被 macOS 拦截，请先确认文件来自本仓库，再到「系统设置 → 隐私与安全性」选择「仍要打开」（如果系统提供该选项）。见 [Apple 的首次打开说明](https://support.apple.com/zh-cn/102445)。 也可以使用下方的源码安装方式。

已构建 App 的最低系统版本为 macOS 13。源码构建需要 Xcode 26 或更新版本的开发工具，包含 macOS 26 SDK 或更新版本。当前验证覆盖 Apple Silicon，Intel 尚未验证。源码构建不需要付费 Apple Developer 会员。项目没有第三方 Swift Package 依赖。

### 让本机 AI agent 帮你安装

复制下面这一句到能够操作这台 Mac 终端的 agent：

> 请按 https://raw.githubusercontent.com/viowai/7viow-talis/main/docs/agent-install.md 中的说明，在我的这台 Mac 上安装并打开 Talis，保留已有模板和设置，并带我完成第一次使用。

Codex 本机源码路径已验证。Claude Code、Cursor、Gemini CLI、VS Code 本地 agent 等在具备相应权限时可使用同一份指引，尚未逐宿主实测。系统确认和首次 AI 服务配置由你完成。仅网页聊天或云端 Linux 任务无法直接安装到这台 Mac。详见 [agent 安装指引](docs/agent-install.md)。

### 自己从源码安装

在 Mac 终端执行：

```bash
git clone https://github.com/viowai/7viow-talis.git
cd 7viow-talis
bash scripts/install_app.sh && open /Applications/Talis.app
```

如果缺少 Apple 开发工具，先运行 `xcode-select --install` 并完成系统提示。已有 Talis 时，先保留正在编辑的文字并退出，再安装。安装器会备份原 App，个人模板和设置独立保留。具体步骤和故障处理见[安装说明](docs/install.md)。

## 完成第一次使用

按 `Option + Space` 唤起 Talis，试着输入这份草稿。

> 我准备把 Talis v1.0.0 发到 GitHub 和 viow.ai。发布前先帮我核对版本、产品功能和发布渠道。发布文案要有中英文，以后也沿用这个规则。再给小红书、X 和朋友圈规划图文和视频。

编辑草稿和按 `Command + Return` 复制都无需配置 AI 服务。想跟着官网体验完整流程，点击右上角齿轮打开「AI 服务设置」，选择「API Key」或「订阅共享」，选好服务和区域后保存。

1. **追问**先问用什么资料复核版本与产品信息。选择以自己提供的资料为准。
2. **重构**把草稿整理成三个任务：复核发布信息、准备双语文案、规划社媒素材。
3. **微调**把复核条件写清楚：先交完整复核包，等你确认后再发布。
4. **复制 Prompt**把结果放进剪贴板。按 `Command + Return`，再粘贴到常用的 AI 工具。

三种编辑操作可以单独使用，结果也可以继续编辑。

“修改记录 · N 轮”打开独立窗口。从“模板”菜单打开“模板中心”，可存为新模板或更新来源模板，清空留在内容区。模板卡片只负责选中，点击“应用”或“替换”才应用；可按 ⌘Z 撤销。【占位符】只提供高亮与定位；括号、冒号和正文均可自由编辑或删除，Tab 跳到下一处。复制与保存保留实际文字。

## 按任务选择起点

| 当前情况 | 用法 |
|---|---|
| 想法还模糊 | 先写下来，再选择追问；缺少关键信息时逐题补齐或跳过 |
| 已经写好请求 | 直接复制，或点击“微调”“重构”调整内容 |
| 经常做相同任务 | 从“模板”菜单打开“模板中心”，或按 `Command + K` 搜索模板；空输入时也可按 `/`。用 Tab 填写占位符 |

系统模板覆盖写作、改稿、PPT、界面设计与评审、资产研究和研究建站。把整理好的请求复制给相应 AI 工具或 skill/s，接着完成专业任务。Talis 可以独立使用，具体交接示例见[与 skill/s 配合](docs/with-skills.md)。

## AI 服务与数据

编辑、模板填空和复制可离线使用。AI 微调、重新生成、追问和 AI 生成模板需要所选服务可用：API Key 厂商按量计费；订阅共享使用本机已登录的对应 AI 产品订阅，不需要另填 API Key。

API Key 组包括 DeepSeek、Kimi、MiniMax、OpenAI API、Anthropic、Google、xAI、腾讯混元、百度文心、阿里通义、字节豆包和智谱 GLM。订阅共享按本机共享网关实际暴露的服务动态列出；当前本机验证可见 Codex、OpenAI、Kimi Work 和 DeepSeek。设置中只显示服务入口，模型版本由 Talis 管理。新安装默认使用 DeepSeek。

Talis 优先采用官方持续更新的模型别名，其余在使用 AI 时自动查询厂商模型目录，选择同一效率或常规系列中的新正式版本。目录最多每 24 小时刷新一次，获取失败会保留已有选择。厂商更改接口或模型命名体系时，可能仍需更新 App。

模型、账号与区域可用性取决于各自服务。API Key 按厂商分别保存在 macOS 钥匙串中；订阅共享只使用本机已经登录的产品订阅，不复制或保存其 OAuth token。配置方法见 [AI 服务设置](docs/ai-services.md)，数据处理见[隐私与数据](docs/privacy.md)。

在模板中心的“我的”页点击“管理”可以新增或修改个人模板。切换条目、搜索、关闭窗口或退出 App 时，如有未保存的编辑，会先让你选择继续编辑或放弃修改。

AI 处理中会锁定当前原文，并在主动作位置显示“停止”。停止后可以继续编辑，晚到结果不会覆盖新输入。请求失败会在标题下保留提示，点击“详情…”查看完整错误。

## 快捷键

| 操作 | 快捷键 |
|---|---|
| 切换主窗口显示 | Option + Space |
| 打开模板搜索 | Command + K，或在空输入时按 / |
| 模板搜索中切换来源 | Tab |
| 编辑时跳到下一占位符 | Tab |
| 插入选中模板 | Return |
| 撤销 | Command + Z |
| 复制 | Command + Return |
| 收起模板选择 | Escape |
| 结束当前快速会话并收起 | Escape |
| 停止 AI 操作 | Command + . |
| 结束追问 | Command + . |
| 保存模板 | Command + S |
| 保存 AI 服务设置 | Command + S |

## 构建与检查

只构建，不替换已安装的 App：

```bash
bash scripts/build_desktop_app.sh
```

产物在 `~/Library/Caches/Talis/Build.noindex/desktop/Talis.app`。检查构建环境用 `bash scripts/check_environment.sh`，检查安装条件用 `bash scripts/install_app.sh --check`。预检只报告环境条件，不构建或安装 App，也不读取 API Key。

## 使用边界与反馈

追问在独立模态窗口中完成，每轮提供 1–3 个问题，最多 5 轮。信息完整时可直接生成最终 Prompt；请求失败时保留原文和本轮回答，并显示明确的原因与重试入口。3 轮上下文服务于当前编辑过程，没有跨设备同步或长期记忆。Esc、关闭窗口或快捷键收起都会结束当前快速会话，下次唤起从空白开始；最近一次正文与修改记录可在主界面的“恢复上次草稿”或 `Prompt > 恢复上次草稿` 中恢复。完全退出 App 后不会自动保存草稿。清空会同时移除当前修改记录，可用 Command + Z 撤销。

菜单栏的 T 图标使用单色模板图像。单击打开或收起 Talis，右击显示新建 Prompt、恢复上次草稿、修改记录、模板、设置、关于和退出菜单。

Talis 通过复制文本与其他工具配合，不自动发送请求、传输附件或安装、执行外部 Agent Skills。Prompt Service 和 Talis Codex 不包含在本桌面版中。

遇到问题，请在 [GitHub Issues](https://github.com/viowai/7viow-talis/issues) 提供 App 版本、macOS 版本、芯片类型、操作步骤和错误信息。版本可从应用菜单的“关于 Talis”查看。反馈前移除 API Key 和私人材料。

## 许可与署名

维护者 Viow，Talis 属于 7viow 产品系列。应用源码及原创文档采用 [Apache License 2.0](LICENSE)，Copyright 2026 Wenbin Li。版权声明见 [NOTICE](NOTICE)。

Montserrat 字体采用独立的 SIL Open Font License 1.1。原作者署名及完整许可见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) 和[字体许可](Resources/Fonts/OFL.txt)。
